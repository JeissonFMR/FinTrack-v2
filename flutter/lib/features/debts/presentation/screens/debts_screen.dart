import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/thousands_input_formatter.dart';
import '../providers/debts_provider.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDebtSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      body: debtsAsync.when(
        data: (data) {
          final debts = data['debts'] as List? ?? [];
          final iOwe = Formatters.decimal(data['iOwe']);
          final owedToMe = Formatters.decimal(data['owedToMe']);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(debtsProvider),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                _SummaryRow(iOwe: iOwe, owedToMe: owedToMe),
                const SizedBox(height: 24),
                if (debts.isEmpty)
                  const _EmptyDebts()
                else ...[
                  const Text('Detalle',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...debts.map((d) => _DebtCard(
                        debt: d,
                        onPayment: () => _showPaymentSheet(context, ref, d),
                      )),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, st) => Center(
          child: Text('$err', style: const TextStyle(color: AppColors.expense)),
        ),
      ),
    );
  }

  void _showAddDebtSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddDebtSheet(ref: ref),
    );
  }

  void _showPaymentSheet(BuildContext context, WidgetRef ref, dynamic debt) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registrar pago — "${debt['name']}"',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            Text(
              'Pendiente: ${Formatters.currency(Formatters.decimal(debt['remainingAmount']), symbol: '\$')}',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [const ThousandsInputFormatter()],
              autofocus: true,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: '\$ ',
                prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final amount = ThousandsInputFormatter.parse(ctrl.text);
                if (amount == null || amount <= 0) return;
                final nav = Navigator.of(ctx);
                await ref
                    .read(debtActionsProvider.notifier)
                    .recordPayment(debt['id'], amount);
                nav.pop();
              },
              child: const Text('Registrar pago'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final double iOwe;
  final double owedToMe;
  const _SummaryRow({required this.iOwe, required this.owedToMe});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Debo',
            amount: iOwe,
            color: AppColors.expense,
            bgColor: AppColors.expenseLight,
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Me deben',
            amount: owedToMe,
            color: AppColors.income,
            bgColor: AppColors.incomeLight,
            icon: Icons.arrow_downward_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color bgColor;
  final IconData icon;
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            Formatters.currency(amount, symbol: '\$'),
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final dynamic debt;
  final VoidCallback onPayment;
  const _DebtCard({required this.debt, required this.onPayment});

  @override
  Widget build(BuildContext context) {
    final isOwnedByMe = debt['type'] == 'OWED_BY_ME';
    final remaining = Formatters.decimal(debt['remainingAmount']);
    final total = Formatters.decimal(debt['totalAmount']);
    final progress = total > 0 ? (1 - remaining / total).clamp(0.0, 1.0) : 1.0;
    final isPaid = debt['isPaid'] == true;
    final dueDate = debt['dueDate'] != null ? DateTime.parse(debt['dueDate']) : null;
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && !isPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid
              ? AppColors.income
              : isOverdue
                  ? AppColors.expense
                  : context.colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isOwnedByMe ? AppColors.expenseLight : AppColors.incomeLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOwnedByMe ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isOwnedByMe ? AppColors.expense : AppColors.income,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      [
                        if (debt['contactName'] != null) debt['contactName'] as String,
                        if (dueDate != null)
                          isOverdue
                              ? 'Vencido: ${Formatters.date(dueDate)}'
                              : 'Vence: ${Formatters.date(dueDate)}',
                      ].join(' · '),
                      style: TextStyle(
                        color: isOverdue ? AppColors.expense : context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPaid)
                TextButton(
                  onPressed: onPayment,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Pagar'),
                ),
              if (isPaid)
                const Icon(Icons.check_circle_outline, color: AppColors.income, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.colors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOwnedByMe ? AppColors.expense : AppColors.income,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPaid ? 'Pagado' : 'Pendiente: ${Formatters.currency(remaining, symbol: '\$')}',
                style: TextStyle(
                  fontSize: 12,
                  color: isPaid ? AppColors.income : context.colors.textSecondary,
                  fontWeight: isPaid ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Text(
                'Total: ${Formatters.currency(total, symbol: '\$')}',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddDebtSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddDebtSheet({required this.ref});

  @override
  State<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<_AddDebtSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _type = 'OWED_BY_ME';
  DateTime? _dueDate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nueva deuda',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 16),
          // Tipo
          Row(
            children: [
              Expanded(child: _TypeBtn('Yo debo', 'OWED_BY_ME', _type, (v) => setState(() => _type = v))),
              const SizedBox(width: 10),
              Expanded(child: _TypeBtn('Me deben', 'OWED_TO_ME', _type, (v) => setState(() => _type = v))),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'Descripción'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [const ThousandsInputFormatter()],
            decoration: const InputDecoration(hintText: 'Monto total', prefixText: '\$ '),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactCtrl,
            decoration: const InputDecoration(hintText: 'Nombre del contacto (opcional)'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(
                _dueDate != null
                    ? Formatters.date(_dueDate!)
                    : 'Fecha de vencimiento (opcional)',
                style: TextStyle(
                  color: _dueDate != null ? context.colors.textPrimary : context.colors.textHint,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              final amount = ThousandsInputFormatter.parse(_amountCtrl.text);
              if (name.isEmpty || amount == null || amount <= 0) return;
              final nav = Navigator.of(context);
              await widget.ref.read(debtActionsProvider.notifier).create(
                    name: name,
                    type: _type,
                    totalAmount: amount,
                    contactName: _contactCtrl.text.trim().isNotEmpty
                        ? _contactCtrl.text.trim()
                        : null,
                    dueDate: _dueDate?.toIso8601String(),
                  );
              if (mounted) nav.pop();
            },
            child: const Text('Crear deuda'),
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
  final ValueChanged<String> onChanged;
  const _TypeBtn(this.label, this.value, this.selected, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final color = value == 'OWED_BY_ME' ? AppColors.expense : AppColors.income;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : context.colors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? color : context.colors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.handshake_outlined, size: 48, color: context.colors.textHint),
            const SizedBox(height: 12),
            Text('Sin deudas registradas',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Toca + para agregar una deuda',
                style: TextStyle(color: context.colors.textHint, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
