import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/budget_alert_manager.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/thousands_input_formatter.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/transactions_provider.dart';

/// Modal completo que escucha la voz del usuario, parsea con IA,
/// muestra los datos pre-llenados y permite crear categoría on-the-fly.
class VoiceTxSheet extends ConsumerStatefulWidget {
  const VoiceTxSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const VoiceTxSheet(),
    );
  }

  @override
  ConsumerState<VoiceTxSheet> createState() => _VoiceTxSheetState();
}

enum _Phase { listening, parsing, confirm, saving }

class _VoiceTxSheetState extends ConsumerState<VoiceTxSheet> {
  final _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  String? _localeId;
  _Phase _phase = _Phase.listening;
  String _spokenText = '';
  String _error = '';

  // Datos parseados / editables
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'EXPENSE';
  String? _accountId;
  String? _categoryId;
  String? _suggestedCategoryName;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _speech.stop();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    // Si hay una sesión previa abierta, ciérrala y espera un instante
    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Inicializar solo una vez (las callbacks se registran una sola vez)
    if (!_speechInitialized) {
      final ok = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _phase = _Phase.confirm;
              _error = 'No te entendí: ${e.errorMsg}';
            });
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted &&
                _phase == _Phase.listening &&
                _spokenText.isNotEmpty) {
              _parse();
            }
          }
        },
      );
      if (!ok) {
        setState(() {
          _phase = _Phase.confirm;
          _error = 'Reconocimiento de voz no disponible';
        });
        return;
      }
      _speechInitialized = true;

      // Detectar locale español una vez
      final locales = await _speech.locales();
      final spanish = locales.firstWhere(
        (l) => l.localeId.startsWith('es'),
        orElse: () => stt.LocaleName('', ''),
      );
      _localeId = spanish.localeId.isEmpty ? null : spanish.localeId;
    }

    // Reset del texto antes de empezar
    if (mounted) setState(() => _spokenText = '');

    try {
      await _speech.listen(
        localeId: _localeId,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() => _spokenText = result.recognizedWords);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.confirm;
          _error = 'No pude iniciar el micrófono: $e';
        });
      }
    }
  }

  Future<void> _stopAndParse() async {
    await _speech.stop();
    _parse();
  }

  Future<void> _parse() async {
    if (_spokenText.trim().isEmpty) {
      setState(() {
        _phase = _Phase.confirm;
        _error = 'No escuché nada. Toca el mic e intenta de nuevo.';
      });
      return;
    }

    setState(() => _phase = _Phase.parsing);

    try {
      final api = ref.read(apiClientProvider);
      final storage = ref.read(tokenStorageProvider);
      final workspaceId = await storage.getWorkspaceId();
      final res = await api.post(
        '/workspaces/$workspaceId/transactions/parse-voice',
        data: {'text': _spokenText},
      );
      final data = Map<String, dynamic>.from(res.data as Map);

      if (data['isTransaction'] != true) {
        setState(() {
          _phase = _Phase.confirm;
          _error = data['reason']?.toString() ??
              'No entendí bien. Intenta más específico.';
        });
        return;
      }

      // Pre-llenar campos
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      _amountCtrl.text = ThousandsInputFormatter()
          .formatEditUpdate(
            const TextEditingValue(text: ''),
            TextEditingValue(text: amount.toStringAsFixed(0)),
          )
          .text;
      _descCtrl.text = (data['description'] as String?) ??
          (data['merchant'] as String?) ?? '';
      _type = (data['type'] as String?) ?? 'EXPENSE';
      _accountId = data['accountId'] as String?;
      _categoryId = data['categoryId'] as String?;
      _suggestedCategoryName = data['categorySuggestion'] as String?;
      final dateStr = data['date'] as String?;
      if (dateStr != null) {
        _date = DateTime.tryParse(dateStr) ?? DateTime.now();
      }

      setState(() {
        _phase = _Phase.confirm;
        _error = '';
      });
    } catch (e) {
      setState(() {
        _phase = _Phase.confirm;
        _error = 'Error: $e';
      });
    }
  }

  Future<void> _createCategoryInline() async {
    final ctrl = TextEditingController(text: _suggestedCategoryName ?? '');
    String type = _type == 'INCOME' ? 'INCOME' : 'EXPENSE';

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Nueva categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'Nombre (ej: Mascotas)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSt(() => type = 'EXPENSE'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: type == 'EXPENSE'
                              ? AppColors.expense.withValues(alpha: 0.1)
                              : null,
                          border: Border.all(
                              color: type == 'EXPENSE'
                                  ? AppColors.expense
                                  : ctx.colors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Gasto',
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSt(() => type = 'INCOME'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: type == 'INCOME'
                              ? AppColors.income.withValues(alpha: 0.1)
                              : null,
                          border: Border.all(
                              color: type == 'INCOME'
                                  ? AppColors.income
                                  : ctx.colors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Ingreso',
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                try {
                  final api = ref.read(apiClientProvider);
                  final storage = ref.read(tokenStorageProvider);
                  final workspaceId = await storage.getWorkspaceId();
                  final res = await api.post(
                    '/workspaces/$workspaceId/categories',
                    data: {
                      'name': name,
                      'type': type,
                      'color': '#10B981',
                      'icon': 'tag',
                    },
                  );
                  if (ctx.mounted) {
                    Navigator.pop(
                        ctx, Map<String, dynamic>.from(res.data as Map));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (created != null) {
      ref.invalidate(categoriesProvider);
      setState(() {
        _categoryId = created['id'] as String;
        _suggestedCategoryName = null;
      });
    }
  }

  Future<void> _save() async {
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una cuenta')),
      );
      return;
    }
    final amount = ThousandsInputFormatter.parse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monto inválido')),
      );
      return;
    }

    setState(() => _phase = _Phase.saving);

    try {
      final api = ref.read(apiClientProvider);
      final storage = ref.read(tokenStorageProvider);
      final workspaceId = await storage.getWorkspaceId();

      await api.post('/workspaces/$workspaceId/transactions', data: {
        'accountId': _accountId,
        'categoryId': _categoryId,
        'type': _type,
        'amount': amount,
        'description': _descCtrl.text.trim().isEmpty
            ? _spokenText
            : _descCtrl.text.trim(),
        'date': _date.toIso8601String(),
      });

      ref.read(transactionsPaginationProvider.notifier).refresh();
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.read(budgetAlertManagerProvider).checkBudgets();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      String detail = 'Error al guardar';
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is Map && resp['message'] is Map) {
          final inner = (resp['message'] as Map)['message'];
          if (inner is List) {
            detail = inner.join(', ');
          } else if (inner is String) {
            detail = inner;
          }
        }
      }
      if (mounted) {
        setState(() => _phase = _Phase.confirm);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: switch (_phase) {
        _Phase.listening => _buildListening(),
        _Phase.parsing => _buildParsing(),
        _Phase.confirm => _buildConfirm(),
        _Phase.saving => _buildSaving(),
      },
    );
  }

  Widget _buildListening() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.expense.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, size: 40, color: AppColors.expense),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Te escucho...',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          _spokenText.isEmpty
              ? 'Di algo como "gasté 25 mil en almuerzo"'
              : '"$_spokenText"',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: _spokenText.isEmpty
                ? context.colors.textHint
                : context.colors.textPrimary,
            fontStyle: _spokenText.isEmpty ? FontStyle.italic : null,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: _stopAndParse,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Listo'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildParsing() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 16),
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 20),
        Text(
          'Procesando con IA...',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSaving() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 16),
        CircularProgressIndicator(color: AppColors.primary),
        SizedBox(height: 20),
        Text('Guardando...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(height: 32),
      ],
    );
  }

  Widget _buildConfirm() {
    final accountsAsync = ref.watch(accountsListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final isIncome = _type == 'INCOME';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mic, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Por voz',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    _phase = _Phase.listening;
                    _spokenText = '';
                    _error = '';
                  });
                  _startListening();
                },
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Repetir',
              ),
            ],
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error,
                  style: const TextStyle(
                      color: AppColors.expense, fontSize: 12)),
            ),
          ],
          if (_spokenText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('"$_spokenText"',
                style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textHint,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 16),

          // Type chips
          Row(
            children: [
              Expanded(
                child: _TypeBtn(
                  label: 'Gasto',
                  value: 'EXPENSE',
                  selected: _type,
                  onTap: (v) => setState(() => _type = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeBtn(
                  label: 'Ingreso',
                  value: 'INCOME',
                  selected: _type,
                  onTap: (v) => setState(() => _type = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Monto
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [const ThousandsInputFormatter()],
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
            decoration: const InputDecoration(
              prefixText: '\$ ',
              prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(hintText: 'Descripción'),
          ),
          const SizedBox(height: 14),

          // Cuenta
          accountsAsync.when(
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _accountId,
              hint: const Text('Cuenta'),
              isExpanded: true,
              items: list
                  .map((a) => DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text(a['name'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _accountId = v),
              decoration: const InputDecoration(),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),

          // Categoría con opción de crear inline
          categoriesAsync.when(
            data: (list) {
              final filtered = list.where((c) {
                final t = c['type'] as String;
                return isIncome
                    ? (t == 'INCOME' || t == 'BOTH')
                    : (t == 'EXPENSE' || t == 'BOTH');
              }).toList();

              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      hint: Text(_suggestedCategoryName != null
                          ? 'Sugerencia IA: "$_suggestedCategoryName" — créala →'
                          : 'Categoría (opcional)'),
                      isExpanded: true,
                      items: filtered
                          .map((c) => DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text(c['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                      decoration: const InputDecoration(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _createCategoryInline,
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                    tooltip: 'Crear categoría',
                  ),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Fecha
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(Formatters.date(_date)),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Registrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;
  const _TypeBtn({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final color =
        value == 'EXPENSE' ? AppColors.expense : AppColors.income;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.1) : context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? color : context.colors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? color : context.colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
