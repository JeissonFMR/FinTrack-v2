import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/thousands_input_formatter.dart';
import '../providers/goals_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return const _EmptyGoals();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(goalsProvider),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: goals.length,
              separatorBuilder: (_, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _GoalCard(
                goal: goals[i],
                onAddProgress: () => _showProgressSheet(context, ref, goals[i]),
                onEdit: () => _showAddGoalSheet(context, ref, existing: goals[i]),
                onDelete: () => _confirmDelete(context, ref, goals[i]),
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

  void _showAddGoalSheet(BuildContext context, WidgetRef ref, {dynamic existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddGoalSheet(ref: ref, existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: Text('¿Eliminar "${goal['name']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goalActionsProvider.notifier).delete(goal['id'] as String);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showProgressSheet(BuildContext context, WidgetRef ref, dynamic goal) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Abonar a "${goal['name']}"',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
                await ref.read(goalActionsProvider.notifier)
                    .addProgress(goal['id'], amount);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Abonar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final dynamic goal;
  final VoidCallback onAddProgress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _GoalCard({
    required this.goal,
    required this.onAddProgress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final target = Formatters.decimal(goal['targetAmount']);
    final current = Formatters.decimal(goal['currentAmount']);
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).toInt();
    final color = _hexColor(goal['color'] as String? ?? '#10B981');
    final isCompleted = goal['status'] == 'COMPLETED';

    return GestureDetector(
      onLongPress: () => _showMenu(context),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? AppColors.income : context.colors.border,
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_outline : Icons.flag_outlined,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (goal['deadline'] != null)
                      Text(
                        'Meta: ${Formatters.date(DateTime.parse(goal['deadline']))}',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (!isCompleted)
                TextButton(
                  onPressed: onAddProgress,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Abonar'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.colors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? AppColors.income : color,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.currency(current, symbol: '\$'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '$pct% · Meta: ${Formatters.currency(target, symbol: '\$')}',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ));
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
              title: const Text('Editar meta'),
              onTap: () { Navigator.pop(ctx); onEdit(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: const Text('Eliminar meta', style: TextStyle(color: AppColors.expense)),
              onTap: () { Navigator.pop(ctx); onDelete(); },
            ),
          ],
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _AddGoalSheet extends StatefulWidget {
  final WidgetRef ref;
  final dynamic existing;
  const _AddGoalSheet({required this.ref, this.existing});

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  DateTime? _deadline;
  String _color = '#10B981';

  final _colors = ['#10B981', '#18181B', '#F97316', '#EAB308', '#EF4444', '#06B6D4'];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    if (g != null) {
      _nameCtrl.text = g['name'] as String? ?? '';
      _targetCtrl.text = ThousandsInputFormatter()
          .formatEditUpdate(
            const TextEditingValue(text: ''),
            TextEditingValue(
                text: Formatters.decimal(g['targetAmount']).toStringAsFixed(0)),
          )
          .text;
      _color = g['color'] as String? ?? '#10B981';
      final dl = g['deadline'] as String?;
      if (dl != null) _deadline = DateTime.parse(dl);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEditing ? 'Editar meta' : 'Nueva meta',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'Nombre de la meta'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [const ThousandsInputFormatter()],
            decoration: const InputDecoration(
              hintText: 'Monto objetivo',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 90)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _deadline = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(
                _deadline != null
                    ? Formatters.date(_deadline!)
                    : 'Fecha límite (opcional)',
                style: TextStyle(
                  color: _deadline != null ? context.colors.textPrimary : context.colors.textHint,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: _colors.map((hex) {
              final c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
              final selected = hex == _color;
              return GestureDetector(
                onTap: () => setState(() => _color = hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 10),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: selected
                        ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              final target = ThousandsInputFormatter.parse(_targetCtrl.text);
              if (name.isEmpty || target == null || target <= 0) return;

              final nav = Navigator.of(context);
              if (_isEditing) {
                await widget.ref.read(goalActionsProvider.notifier).edit(
                  widget.existing['id'] as String,
                  {
                    'name': name,
                    'targetAmount': target,
                    'color': _color,
                    if (_deadline != null) 'deadline': _deadline!.toIso8601String(),
                  },
                );
              } else {
                await widget.ref.read(goalActionsProvider.notifier).create(
                  name: name,
                  targetAmount: target,
                  deadline: _deadline?.toIso8601String(),
                  color: _color,
                );
              }

              if (mounted) nav.pop();
            },
            child: Text(_isEditing ? 'Guardar cambios' : 'Crear meta'),
          ),
        ],
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 48, color: context.colors.textHint),
          const SizedBox(height: 12),
          Text('Sin metas aún',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Toca + para crear tu primera meta',
              style: TextStyle(color: context.colors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}
