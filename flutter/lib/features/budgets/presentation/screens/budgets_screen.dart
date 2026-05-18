import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../providers/budgets_provider.dart';

const _periods = [
  ('MONTHLY', 'Mensual'),
  ('WEEKLY', 'Semanal'),
  ('YEARLY', 'Anual'),
];

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return const _EmptyBudgets();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(budgetsProvider),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: budgets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _BudgetCard(
                budget: budgets[i],
                onEdit: () => _showSheet(context, ref, existing: budgets[i]),
                onDelete: () => _confirmDelete(context, ref, budgets[i]),
              ),
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

  void _showSheet(BuildContext context, WidgetRef ref, {dynamic existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BudgetSheet(ref: ref, existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic budget) {
    final name = (budget['category'] as Map)['name'] as String;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar presupuesto'),
        content: Text('¿Eliminar el presupuesto de "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(budgetActionsProvider.notifier).delete(budget['id'] as String);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final dynamic budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BudgetCard({required this.budget, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final category = budget['category'] as Map;
    final amount = Formatters.decimal(budget['amount']);
    final spent = Formatters.decimal(budget['spent']);
    final percentage = Formatters.decimal(budget['percentage']).toInt();
    final color = _hexColor(category['color'] as String? ?? '#18181B');
    final periodLabel = _periodLabel(budget['period'] as String? ?? 'MONTHLY');

    final isOver = percentage >= 100;
    final isAlert = percentage >= 80 && !isOver;
    final barColor = isOver ? AppColors.expense : isAlert ? Colors.orange : AppColors.income;

    return GestureDetector(
      onLongPress: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOver ? AppColors.expense.withValues(alpha: 0.4) : context.colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(categoryIcon(category['icon'] as String?), color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(periodLabel,
                          style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isOver ? AppColors.expense : context.colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                backgroundColor: context.colors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gastado: ${Formatters.currency(spent, symbol: '\$')}',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                Text('de ${Formatters.currency(amount, symbol: '\$')}',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar presupuesto'),
              onTap: () { Navigator.pop(ctx); onEdit(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: const Text('Eliminar presupuesto',
                  style: TextStyle(color: AppColors.expense)),
              onTap: () { Navigator.pop(ctx); onDelete(); },
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(String period) => switch (period) {
        'WEEKLY' => 'Semanal',
        'MONTHLY' => 'Mensual',
        'YEARLY' => 'Anual',
        _ => period,
      };

  Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _BudgetSheet extends StatefulWidget {
  final WidgetRef ref;
  final dynamic existing;
  const _BudgetSheet({required this.ref, this.existing});

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  final _amountCtrl = TextEditingController();
  String _period = 'MONTHLY';
  String? _categoryId;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _alertAt = 80;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amountCtrl.text = Formatters.decimal(e['amount']).toStringAsFixed(0);
      _period = e['period'] as String? ?? 'MONTHLY';
      _categoryId = (e['category'] as Map?)?['id'] as String?;
      _alertAt = (e['alertAt'] as num?)?.toInt() ?? 80;
      final sd = e['startDate'] as String?;
      if (sd != null) _startDate = DateTime.parse(sd);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = widget.ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEditing ? 'Editar presupuesto' : 'Nuevo presupuesto',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 20),

          // Categoría
          const Text('Categoría', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          categoriesAsync.when(
            data: (cats) {
              final expenseCats = cats
                  .where((c) => c['type'] == 'EXPENSE' || c['type'] == 'BOTH')
                  .toList();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: context.colors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _categoryId,
                    isExpanded: true,
                    hint: Text('Selecciona una categoría',
                        style: TextStyle(color: context.colors.textHint)),
                    items: expenseCats.map<DropdownMenuItem<String>>((c) {
                      return DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ),
              );
            },
            loading: () => const CircularProgressIndicator(strokeWidth: 2),
            error: (_, _) => const Text('Error cargando categorías'),
          ),
          const SizedBox(height: 14),

          // Monto
          const Text('Monto límite', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              prefixText: '\$ ',
              prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),

          // Período
          const Text('Período', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: _periods.map((p) {
              final selected = _period == p.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _period = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: p.$1 != 'YEARLY' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : context.colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppColors.primary : context.colors.border,
                      ),
                    ),
                    child: Text(
                      p.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? Colors.white : context.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Fecha de inicio
          const Text('Desde', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _startDate = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(Formatters.date(_startDate),
                  style: const TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 14),

          // Alerta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Alerta al', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('$_alertAt%', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: _alertAt.toDouble(),
            min: 50,
            max: 100,
            divisions: 10,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _alertAt = v.toInt()),
          ),
          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(
                  _amountCtrl.text.replaceAll(',', '.'));
              if (amount == null || amount <= 0 || _categoryId == null) return;

              final nav = Navigator.of(context);
              final data = {
                'categoryId': _categoryId,
                'amount': amount,
                'period': _period,
                'startDate': _startDate.toIso8601String().split('T').first,
                'alertAt': _alertAt,
              };

              if (_isEditing) {
                await widget.ref
                    .read(budgetActionsProvider.notifier)
                    .edit(widget.existing['id'] as String, data);
              } else {
                await widget.ref
                    .read(budgetActionsProvider.notifier)
                    .create(data);
              }
              if (mounted) nav.pop();
            },
            child: Text(_isEditing ? 'Guardar cambios' : 'Crear presupuesto'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.donut_large_outlined, size: 48, color: context.colors.textHint),
          const SizedBox(height: 12),
          Text('Sin presupuestos aún',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Toca + para crear tu primer presupuesto',
              style: TextStyle(color: context.colors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}
