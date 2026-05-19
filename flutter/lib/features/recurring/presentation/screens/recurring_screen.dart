import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/thousands_input_formatter.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../providers/recurring_provider.dart';

const _frequencies = [
  ('DAILY', 'Diario'),
  ('WEEKLY', 'Semanal'),
  ('BIWEEKLY', 'Quincenal'),
  ('MONTHLY', 'Mensual'),
  ('YEARLY', 'Anual'),
];

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(recurringListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurrentes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      body: listAsync.when(
        data: (items) {
          if (items.isEmpty) return const _Empty();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(recurringListProvider),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _RecurringCard(
                item: items[i],
                onTap: () => _showSheet(context, ref, existing: items[i]),
                onRunNow: () => _confirmRunNow(context, ref, items[i]),
                onDelete: () => _confirmDelete(context, ref, items[i]),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppColors.expense)),
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
      builder: (_) => _RecurringSheet(existing: existing),
    );
  }

  void _confirmRunNow(BuildContext context, WidgetRef ref, dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar ahora'),
        content: Text(
          '¿Crear ya la transacción de "${item['name']}" sin esperar a la fecha programada?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(recurringActionsProvider.notifier).runNow(item['id']);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar recurrente'),
        content: Text('¿Eliminar "${item['name']}"? Las transacciones ya creadas no se borran.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(recurringActionsProvider.notifier).delete(item['id']);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onTap;
  final VoidCallback onRunNow;
  final VoidCallback onDelete;
  const _RecurringCard({
    required this.item,
    required this.onTap,
    required this.onRunNow,
    required this.onDelete,
  });

  String _freqLabel(String f) => switch (f) {
        'DAILY' => 'Diario',
        'WEEKLY' => 'Semanal',
        'BIWEEKLY' => 'Quincenal',
        'MONTHLY' => 'Mensual',
        'YEARLY' => 'Anual',
        _ => f,
      };

  Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final amount = Formatters.decimal(item['amount']);
    final type = item['type'] as String;
    final isIncome = type == 'INCOME';
    final cat = item['category'] as Map?;
    final isActive = item['isActive'] == true;
    final nextDue = DateTime.tryParse(item['nextDueDate'] as String? ?? '');
    final color = cat != null
        ? _hex(cat['color'] as String? ?? '#18181B')
        : (isIncome ? AppColors.income : AppColors.expense);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showMenu(context),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      categoryIcon(cat?['icon'] as String?),
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          _freqLabel(item['frequency'] as String),
                          style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isIncome ? '+' : '-'}${Formatters.currency(amount, symbol: '\$')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 13, color: context.colors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    isActive
                        ? (nextDue != null
                            ? 'Próximo: ${Formatters.date(nextDue)}'
                            : 'Próximo: —')
                        : 'Pausado',
                    style: TextStyle(
                        fontSize: 12, color: context.colors.textHint),
                  ),
                  const Spacer(),
                  if (isActive)
                    TextButton.icon(
                      onPressed: onRunNow,
                      icon: const Icon(Icons.bolt_outlined, size: 14),
                      label: const Text('Aplicar ahora',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0),
                        minimumSize: Size.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.expense),
              title: const Text('Eliminar',
                  style: TextStyle(color: AppColors.expense)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringSheet extends ConsumerStatefulWidget {
  final dynamic existing;
  const _RecurringSheet({this.existing});

  @override
  ConsumerState<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<_RecurringSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'EXPENSE';
  String _frequency = 'MONTHLY';
  String? _accountId;
  String? _categoryId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] as String? ?? '';
      _amountCtrl.text = ThousandsInputFormatter()
          .formatEditUpdate(
            const TextEditingValue(text: ''),
            TextEditingValue(
                text: Formatters.decimal(e['amount']).toStringAsFixed(0)),
          )
          .text;
      _descCtrl.text = e['description'] as String? ?? '';
      _type = e['type'] as String? ?? 'EXPENSE';
      _frequency = e['frequency'] as String? ?? 'MONTHLY';
      _accountId = (e['account'] as Map?)?['id'] as String?;
      _categoryId = (e['category'] as Map?)?['id'] as String?;
      _isActive = e['isActive'] == true;
      final s = e['startDate'] as String?;
      if (s != null) _startDate = DateTime.parse(s);
      final end = e['endDate'] as String?;
      if (end != null) _endDate = DateTime.parse(end);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = ThousandsInputFormatter.parse(_amountCtrl.text);
    if (name.isEmpty || amount == null || amount <= 0 || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre, monto y cuenta')),
      );
      return;
    }
    setState(() => _saving = true);

    final data = {
      'name': name,
      'type': _type,
      'amount': amount,
      'accountId': _accountId,
      'categoryId': _categoryId,
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'frequency': _frequency,
      'startDate': _startDate.toIso8601String().split('T').first,
      'endDate': _endDate?.toIso8601String().split('T').first,
      'isActive': _isActive,
    };

    final nav = Navigator.of(context);
    if (_isEditing) {
      await ref
          .read(recurringActionsProvider.notifier)
          .edit(widget.existing['id'] as String, data);
    } else {
      await ref.read(recurringActionsProvider.notifier).create(data);
    }
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Editar recurrente' : 'Nueva recurrente',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Nombre (Netflix, Arriendo, etc.)'),
            ),
            const SizedBox(height: 14),

            // Tipo
            Row(
              children: [
                Expanded(child: _TypeBtn('Gasto', 'EXPENSE', _type, (v) => setState(() => _type = v))),
                const SizedBox(width: 8),
                Expanded(child: _TypeBtn('Ingreso', 'INCOME', _type, (v) => setState(() => _type = v))),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [const ThousandsInputFormatter()],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Monto',
                prefixText: '\$ ',
                prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 14),

            // Frecuencia
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _frequencies.map((f) {
                final selected = _frequency == f.$1;
                return GestureDetector(
                  onTap: () => setState(() => _frequency = f.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : context.colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : context.colors.border,
                      ),
                    ),
                    child: Text(
                      f.$2,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? Colors.white
                            : context.colors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
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

            // Categoría
            categoriesAsync.when(
              data: (list) {
                final filtered = list.where((c) {
                  final t = c['type'] as String;
                  return _type == 'INCOME'
                      ? (t == 'INCOME' || t == 'BOTH')
                      : (t == 'EXPENSE' || t == 'BOTH');
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
            const SizedBox(height: 14),

            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                hintText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 14),

            // Fecha inicio
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
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de inicio',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(Formatters.date(_startDate)),
              ),
            ),
            const SizedBox(height: 14),

            // Fecha fin opcional
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
                  firstDate: _startDate,
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => _endDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha fin (opcional)',
                  suffixIcon: _endDate != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _endDate = null),
                        )
                      : const Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  _endDate != null
                      ? Formatters.date(_endDate!)
                      : 'Sin fecha fin',
                  style: TextStyle(
                    color: _endDate != null
                        ? null
                        : context.colors.textHint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              title: const Text('Activa'),
              subtitle: Text(
                _isActive
                    ? 'Se creará automáticamente según frecuencia'
                    : 'Pausada — no se creará',
                style: TextStyle(
                    fontSize: 12, color: context.colors.textHint),
              ),
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Guardar cambios' : 'Crear recurrente'),
            ),
          ],
        ),
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
    final color =
        value == 'EXPENSE' ? AppColors.expense : AppColors.income;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : context.colors.surface,
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

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.replay_outlined,
              size: 48, color: context.colors.textHint),
          const SizedBox(height: 12),
          Text('Sin transacciones recurrentes',
              style: TextStyle(
                  color: context.colors.textSecondary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Toca + para crear Netflix, salario, arriendo, etc.',
              style: TextStyle(color: context.colors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}
