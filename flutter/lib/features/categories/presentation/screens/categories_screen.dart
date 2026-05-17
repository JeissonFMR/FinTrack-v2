import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../providers/categories_provider.dart';

const _colorOptions = [
  '#18181B', '#10B981', '#EF4444', '#F97316',
  '#EAB308', '#06B6D4', '#8B5CF6', '#EC4899',
  '#3B82F6', '#14B8A6', '#84CC16', '#6B7280',
];

const _icons = [
  ('restaurant', Icons.restaurant_outlined),
  ('cafe', Icons.local_cafe_outlined),
  ('fastfood', Icons.fastfood_outlined),
  ('bar', Icons.local_bar_outlined),
  ('grocery', Icons.local_grocery_store_outlined),
  ('car', Icons.directions_car_outlined),
  ('bus', Icons.directions_bus_outlined),
  ('taxi', Icons.local_taxi_outlined),
  ('flight', Icons.flight_outlined),
  ('bike', Icons.pedal_bike_outlined),
  ('shopping', Icons.shopping_bag_outlined),
  ('cart', Icons.shopping_cart_outlined),
  ('store', Icons.storefront_outlined),
  ('clothes', Icons.checkroom_outlined),
  ('gift', Icons.redeem_outlined),
  ('hospital', Icons.local_hospital_outlined),
  ('fitness', Icons.fitness_center_outlined),
  ('spa', Icons.spa_outlined),
  ('medicine', Icons.medication_outlined),
  ('health', Icons.health_and_safety_outlined),
  ('games', Icons.sports_esports_outlined),
  ('movie', Icons.movie_outlined),
  ('music', Icons.music_note_outlined),
  ('sports', Icons.sports_outlined),
  ('celebration', Icons.celebration_outlined),
  ('home', Icons.home_outlined),
  ('electrical', Icons.electrical_services_outlined),
  ('plumbing', Icons.plumbing_outlined),
  ('cleaning', Icons.cleaning_services_outlined),
  ('school', Icons.school_outlined),
  ('book', Icons.menu_book_outlined),
  ('computer', Icons.computer_outlined),
  ('bank', Icons.account_balance_outlined),
  ('savings', Icons.savings_outlined),
  ('trending', Icons.trending_up_outlined),
  ('credit', Icons.credit_card_outlined),
  ('payments', Icons.payments_outlined),
  ('work', Icons.work_outlined),
  ('business', Icons.business_center_outlined),
  ('money', Icons.attach_money_rounded),
  ('tag', Icons.tag_outlined),
  ('star', Icons.star_outline_rounded),
  ('favorite', Icons.favorite_outline_rounded),
  ('category', Icons.category_outlined),
];


Color _hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSheet(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final income = categories.where((c) {
            final t = c['type'] as String;
            return t == 'INCOME' || t == 'BOTH';
          }).toList();
          final expense = categories.where((c) {
            final t = c['type'] as String;
            return t == 'EXPENSE' || t == 'BOTH';
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(categoriesProvider),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if (income.isNotEmpty) ...[
                  _SectionHeader(label: 'Ingresos'),
                  const SizedBox(height: 8),
                  ...income.map((c) => _CategoryTile(
                        category: c,
                        onTap: () => _showSheet(context, ref, existing: c),
                        onDelete: () => _confirmDelete(context, ref, c),
                      )),
                  const SizedBox(height: 16),
                ],
                if (expense.isNotEmpty) ...[
                  _SectionHeader(label: 'Gastos'),
                  const SizedBox(height: 8),
                  ...expense.map((c) => _CategoryTile(
                        category: c,
                        onTap: () => _showSheet(context, ref, existing: c),
                        onDelete: () => _confirmDelete(context, ref, c),
                      )),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
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
      builder: (ctx) => _CategorySheet(ref: ref, existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${category['name']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(categoryActionsProvider.notifier).delete(category['id'] as String);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.colors.textHint,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final dynamic category;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(category['color'] as String? ?? '#18181B');
    final icon = categoryIcon(category['icon'] as String? ?? 'tag');
    final isDefault = category['isDefault'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          category['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: isDefault
            ? Text('Predeterminada',
                style: TextStyle(color: context.colors.textHint, fontSize: 12))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chevron_right, size: 18, color: context.colors.textHint),
            if (!isDefault)
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.delete_outline, size: 18, color: AppColors.expense),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final WidgetRef ref;
  final dynamic existing;
  const _CategorySheet({required this.ref, this.existing});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _nameCtrl = TextEditingController();
  String _type = 'EXPENSE';
  String _color = '#10B981';
  String _icon = 'tag';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] as String? ?? '';
      _type = e['type'] as String? ?? 'EXPENSE';
      _color = e['color'] as String? ?? '#10B981';
      _icon = e['icon'] as String? ?? 'tag';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Editar categoría' : 'Nueva categoría',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 20),

          // Preview + Name
          Row(
            children: [
              GestureDetector(
                onTap: _showIconPicker,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _hexColor(_color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _hexColor(_color), width: 2),
                  ),
                  child: Icon(categoryIcon(_icon), color: _hexColor(_color), size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Nombre de la categoría'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type
          const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _TypeChip(
                label: 'Gasto',
                selected: _type == 'EXPENSE',
                color: AppColors.expense,
                onTap: () => setState(() => _type = 'EXPENSE'),
              ),
              const SizedBox(width: 8),
              _TypeChip(
                label: 'Ingreso',
                selected: _type == 'INCOME',
                color: AppColors.income,
                onTap: () => setState(() => _type = 'INCOME'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Color picker
          const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _colorOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final hex = _colorOptions[i];
                final selected = hex == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _hexColor(hex),
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: selected
                          ? [BoxShadow(color: _hexColor(hex).withValues(alpha: 0.5), blurRadius: 8)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;
              final nav = Navigator.of(context);
              if (_isEditing) {
                await widget.ref.read(categoryActionsProvider.notifier).edit(
                  widget.existing['id'] as String,
                  {'name': name, 'type': _type, 'icon': _icon, 'color': _color},
                );
              } else {
                await widget.ref.read(categoryActionsProvider.notifier).create(
                  name: name,
                  type: _type,
                  icon: _icon,
                  color: _color,
                );
              }
              if (mounted) nav.pop();
            },
            child: Text(_isEditing ? 'Guardar cambios' : 'Crear categoría'),
          ),
        ],
      ),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Text(
                'Elige un ícono',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _icons.length,
                itemBuilder: (ctx, i) {
                  final (name, iconData) = _icons[i];
                  final selected = name == _icon;
                  final color = _hexColor(_color);
                  return GestureDetector(
                    onTap: () {
                      setState(() => _icon = name);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected ? color.withValues(alpha: 0.15) : context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? color : context.colors.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Icon(
                        iconData,
                        size: 22,
                        color: selected ? color : context.colors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? color : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
