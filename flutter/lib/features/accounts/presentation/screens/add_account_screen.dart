import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/accounts_provider.dart';

const _accountTypes = [
  ('CASH', 'Efectivo', Icons.payments_outlined),
  ('BANK', 'Banco', Icons.account_balance_outlined),
  ('CREDIT_CARD', 'Tarjeta de crédito', Icons.credit_card_outlined),
  ('DIGITAL_WALLET', 'Billetera digital', Icons.phone_android_outlined),
  ('INVESTMENT', 'Inversión', Icons.trending_up_outlined),
  ('SAVINGS', 'Ahorros', Icons.savings_outlined),
];

const _colorOptions = [
  '#18181B', '#10B981', '#EF4444', '#F97316',
  '#EAB308', '#06B6D4', '#8B5CF6', '#EC4899',
  '#3B82F6', '#14B8A6', '#84CC16', '#6B7280',
];

class AddAccountScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? account;
  const AddAccountScreen({super.key, this.account});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0');

  String _type = 'BANK';
  String _color = '#18181B';

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    if (a != null) {
      _nameCtrl.text = a['name'] as String? ?? '';
      _type = a['type'] as String? ?? 'BANK';
      _color = a['color'] as String? ?? '#18181B';
      _balanceCtrl.text = Formatters.decimal(a['balance']).toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditing) {
      await ref.read(accountActionsProvider.notifier).edit(
        widget.account!['id'] as String,
        {
          'name': _nameCtrl.text.trim(),
          'type': _type,
          'color': _color,
        },
      );
      if (mounted) context.pop();
      return;
    }

    await ref.read(createAccountProvider.notifier).create(
          name: _nameCtrl.text.trim(),
          type: _type,
          initialBalance: double.tryParse(
                _balanceCtrl.text.replaceAll(',', '.'),
              ) ??
              0,
          color: _color,
          icon: 'wallet',
        );

    if (mounted) {
      final state = ref.read(createAccountProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al crear la cuenta'),
            backgroundColor: AppColors.expense,
          ),
        );
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(createAccountProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar cuenta' : 'Nueva cuenta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Color picker + nombre
            Row(
              children: [
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _hexColor(_color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _hexColor(_color), width: 2),
                    ),
                    child: Icon(Icons.palette_outlined, color: _hexColor(_color)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Nombre de la cuenta'),
                    validator: (v) =>
                        v != null && v.isNotEmpty ? null : 'Requerido',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tipo de cuenta
            const Text(
              'Tipo de cuenta',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _accountTypes.map((t) {
                final selected = _type == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _type = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? context.colors.primaryLight : context.colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppColors.primary : context.colors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.$3,
                            size: 16,
                            color: selected ? AppColors.primary : context.colors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          t.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? AppColors.primary : context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            if (!_isEditing) ...[
              const Text(
                'Saldo inicial',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  return n == null ? 'Monto inválido' : null;
                },
              ),
            ],
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEditing ? 'Guardar cambios' : 'Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Color',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: _colorOptions.map((hex) {
                final selected = hex == _color;
                return GestureDetector(
                  onTap: () {
                    setState(() => _color = hex);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: _hexColor(hex),
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: selected
                          ? [BoxShadow(color: _hexColor(hex).withValues(alpha: 0.5), blurRadius: 8)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
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
