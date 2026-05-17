import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/budget_alert_manager.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/transactions_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? transaction;
  const AddTransactionScreen({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _type = 'EXPENSE';
  String? _accountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _loading = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx != null) {
      _type = tx['type'] as String? ?? 'EXPENSE';
      _accountId = tx['accountId'] as String? ?? (tx['account'] as Map?)?['id'] as String?;
      _categoryId = tx['categoryId'] as String? ?? (tx['category'] as Map?)?['id'] as String?;
      _descCtrl.text = tx['description'] as String? ?? '';
      _amountCtrl.text = Formatters.decimal(tx['amount']).toStringAsFixed(0);
      final dateStr = tx['date'] as String?;
      if (dateStr != null) _date = DateTime.parse(dateStr);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una cuenta')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final api = ref.read(apiClientProvider);
      final storage = ref.read(tokenStorageProvider);
      final workspaceId = await storage.getWorkspaceId();

      final body = {
        'accountId': _accountId,
        'categoryId': _categoryId,
        'type': _type,
        'amount': double.parse(_amountCtrl.text.replaceAll(',', '.')),
        'description': _descCtrl.text.trim(),
        'date': _date.toIso8601String(),
      };

      if (_isEditing) {
        final txId = widget.transaction!['id'] as String;
        await api.patch('/workspaces/$workspaceId/transactions/$txId', data: body);
      } else {
        await api.post('/workspaces/$workspaceId/transactions', data: body);
      }

      ref.read(transactionsPaginationProvider.notifier).refresh();
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.read(budgetAlertManagerProvider).checkBudgets();

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsListProvider);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Tipo
            _TypeSelector(
              value: _type,
              onChanged: (v) => setState(() {
                _type = v;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 20),

            // Monto
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: '\$ ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa un monto';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Monto inválido';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Descripción
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(hintText: 'Descripción'),
              validator: (v) => v != null && v.isNotEmpty ? null : 'Requerido',
            ),
            const SizedBox(height: 20),

            // Cuenta
            accounts.when(
              data: (list) => _DropdownField(
                hint: 'Cuenta',
                value: _accountId,
                items: list.map((a) => DropdownMenuItem(
                  value: a['id'] as String,
                  child: Text(a['name'] as String),
                )).toList(),
                onChanged: (v) => setState(() => _accountId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Categoría
            if (_type != 'TRANSFER')
              categories.when(
                data: (list) {
                  final filtered = list.where((c) =>
                    (_type == 'INCOME' ? c['type'] == 'INCOME' : c['type'] == 'EXPENSE')
                  ).toList();
                  return _DropdownField(
                    hint: 'Categoría (opcional)',
                    value: _categoryId,
                    items: filtered.map((c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['name'] as String),
                    )).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const SizedBox.shrink(),
              ),
            const SizedBox(height: 16),

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
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  DateFormat('d MMM yyyy', 'es').format(_date),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          _Tab('Gasto', 'EXPENSE', value, onChanged, AppColors.expense),
          _Tab('Ingreso', 'INCOME', value, onChanged, AppColors.income),
          _Tab('Transferencia', 'TRANSFER', value, onChanged, AppColors.primary),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String type;
  final String selected;
  final ValueChanged<String> onChanged;
  final Color color;

  const _Tab(this.label, this.type, this.selected, this.onChanged, this.color);

  @override
  Widget build(BuildContext context) {
    final isSelected = type == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? color : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String hint;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(hint),
      items: items,
      onChanged: onChanged,
      decoration: const InputDecoration(),
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textHint),
    );
  }
}
