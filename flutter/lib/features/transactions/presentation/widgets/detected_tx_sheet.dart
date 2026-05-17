import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/bank_notification_listener.dart';
import '../../../../core/services/budget_alert_manager.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/formatters.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/transactions_provider.dart';

/// Sheet que aparece cuando el listener detecta una transacción.
/// El usuario solo elige cuenta y categoría y confirma.
class DetectedTxSheet extends ConsumerStatefulWidget {
  final ParsedBankTransaction parsed;
  const DetectedTxSheet({super.key, required this.parsed});

  static Future<void> show(BuildContext context, ParsedBankTransaction parsed) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DetectedTxSheet(parsed: parsed),
    );
  }

  @override
  ConsumerState<DetectedTxSheet> createState() => _DetectedTxSheetState();
}

class _DetectedTxSheetState extends ConsumerState<DetectedTxSheet> {
  String? _accountId;
  String? _categoryId;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.parsed.merchant ?? '');
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una cuenta')),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final api = ref.read(apiClientProvider);
      final storage = ref.read(tokenStorageProvider);
      final workspaceId = await storage.getWorkspaceId();

      await api.post('/workspaces/$workspaceId/transactions', data: {
        'accountId': _accountId,
        'categoryId': _categoryId,
        'type': widget.parsed.type ?? 'EXPENSE',
        'amount': widget.parsed.amount,
        'description': _descCtrl.text.trim(),
        'date': (widget.parsed.date ?? DateTime.now().toIso8601String().split('T').first),
      });

      ref.read(transactionsPaginationProvider.notifier).refresh();
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.read(budgetAlertManagerProvider).checkBudgets();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.expense),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final p = widget.parsed;
    final isIncome = p.type == 'INCOME';

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                    Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Detectado por IA',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              if (p.bank != null)
                Text(p.bank!, style: TextStyle(color: context.colors.textHint, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${isIncome ? '+' : '-'}\$${Formatters.currency(p.amount ?? 0, symbol: '')}',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
          const SizedBox(height: 4),
          Text(p.merchant ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          if (p.cardLast4 != null)
            Text('Tarjeta •••• ${p.cardLast4}',
                style: TextStyle(color: context.colors.textHint, fontSize: 12)),
          const SizedBox(height: 20),

          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(hintText: 'Descripción'),
          ),
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),

          categoriesAsync.when(
            data: (list) {
              final filtered = list.where((c) {
                final t = c['type'] as String;
                return isIncome ? (t == 'INCOME' || t == 'BOTH') : (t == 'EXPENSE' || t == 'BOTH');
              }).toList();
              return DropdownButtonFormField<String>(
                initialValue: _categoryId,
                hint: const Text('Categoría (opcional)'),
                isExpanded: true,
                items: filtered
                    .map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['name'] as String),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                decoration: const InputDecoration(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Descartar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _confirm,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Registrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
