import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/theme_provider.dart';
import '../../../../core/services/auto_register_pref.dart';
import '../../../../core/services/bank_notification_listener.dart';
import '../../../../core/services/notifications_pref.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: profileAsync.when(
        data: (profile) => _SettingsBody(profile: profile),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, st) => _SettingsBody(profile: const {}),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  final Map<String, dynamic> profile;
  const _SettingsBody({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = profile['email'] as String?;
    final workspaceName = profile['workspaceName'] as String?;
    final workspaceId = profile['workspaceId'] as String?;
    final initials = email != null && email.isNotEmpty ? email[0].toUpperCase() : '?';
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final autoRegisterOn = ref.watch(autoRegisterEnabledProvider);

    return ListView(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: context.colors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials,
                      style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (email != null)
                      Text(email,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    if (workspaceName != null)
                      Text(workspaceName,
                          style: TextStyle(
                              color: context.colors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 0),

        _SectionHeader(title: 'Espacio de trabajo'),
        ListTile(
          leading: Icon(Icons.business_outlined,
              color: context.colors.textSecondary, size: 22),
          title: Text('Nombre',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(workspaceName ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined,
                  size: 16, color: context.colors.textHint),
            ],
          ),
          onTap: workspaceId != null
              ? () => _editWorkspaceName(context, ref, workspaceId, workspaceName ?? '')
              : null,
        ),

        const Divider(height: 0),

        _SectionHeader(title: 'Cuenta'),
        _InfoTile(
          icon: Icons.email_outlined,
          label: 'Correo',
          value: email ?? '—',
        ),
        ListTile(
          leading: Icon(Icons.lock_outline,
              color: context.colors.textSecondary, size: 22),
          title: Text('Contraseña',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cambiar',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: context.colors.textHint),
            ],
          ),
          onTap: () => _changePassword(context, ref),
        ),

        const Divider(height: 0),

        _SectionHeader(title: 'Personalización'),
        ListTile(
          leading: Icon(Icons.category_outlined,
              color: context.colors.textSecondary, size: 22),
          title: const Text('Categorías', style: TextStyle(fontSize: 14)),
          trailing: Icon(Icons.chevron_right,
              size: 18, color: context.colors.textHint),
          onTap: () => context.push('/categories'),
        ),
        ListTile(
          leading: Icon(Icons.replay_outlined,
              color: context.colors.textSecondary, size: 22),
          title: const Text('Recurrentes', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            'Suscripciones, salario, arriendo',
            style: TextStyle(color: context.colors.textHint, fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right,
              size: 18, color: context.colors.textHint),
          onTap: () => context.push('/recurring'),
        ),
        ListTile(
          leading: Icon(Icons.dark_mode_outlined,
              color: context.colors.textSecondary, size: 22),
          title: const Text('Modo oscuro', style: TextStyle(fontSize: 14)),
          trailing: Switch(
            value: isDark,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ),
        ListTile(
          leading: Icon(Icons.notifications_outlined,
              color: context.colors.textSecondary, size: 22),
          title: const Text('Notificaciones', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            'Alertas de presupuestos y deudas',
            style: TextStyle(color: context.colors.textHint, fontSize: 12),
          ),
          trailing: Switch(
            value: notificationsOn,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            onChanged: (_) =>
                ref.read(notificationsEnabledProvider.notifier).toggle(),
          ),
        ),
        ListTile(
          leading: Icon(Icons.bolt_outlined,
              color: context.colors.textSecondary, size: 22),
          title: const Text('Registrar automáticamente',
              style: TextStyle(fontSize: 14)),
          subtitle: Text(
            'Si la IA detecta todo (cuenta, categoría y monto), se registra solo',
            style: TextStyle(color: context.colors.textHint, fontSize: 12),
          ),
          trailing: Switch(
            value: autoRegisterOn,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            onChanged: (_) =>
                ref.read(autoRegisterEnabledProvider.notifier).toggle(),
          ),
        ),
        ListTile(
          leading: Icon(Icons.auto_awesome_outlined,
              color: context.colors.textSecondary, size: 22),
          title: const Text('Detección automática', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            'Lee notificaciones bancarias y propone registrarlas',
            style: TextStyle(color: context.colors.textHint, fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right,
              size: 18, color: context.colors.textHint),
          onTap: () async {
            final listener = ref.read(bankNotificationListenerProvider);
            final has = await listener.hasPermission();
            if (has) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ya tienes el permiso activo')),
                );
              }
              return;
            }
            final granted = await listener.requestPermission();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(
                    granted ? 'Permiso otorgado' : 'Permiso no otorgado')),
              );
            }
          },
        ),

        const Divider(height: 0),

        _SectionHeader(title: 'Aplicación'),
        _InfoTile(
          icon: Icons.info_outline,
          label: 'Versión',
          value: '1.0.0',
        ),

        const SizedBox(height: 24),
        const Divider(height: 0),

        ListTile(
          leading: const Icon(Icons.logout_rounded, color: AppColors.expense),
          title: const Text('Cerrar sesión',
              style: TextStyle(
                  color: AppColors.expense, fontWeight: FontWeight.w500)),
          onTap: () => _confirmLogout(context, ref),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  void _editWorkspaceName(
      BuildContext context, WidgetRef ref, String workspaceId, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del workspace'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final error = await ref
                  .read(profileActionsProvider.notifier)
                  .updateWorkspaceName(workspaceId, name);
              if (error != null && ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text(error),
                  backgroundColor: AppColors.expense,
                ));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _changePassword(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Contraseña actual',
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                final current = currentCtrl.text;
                final newPass = newCtrl.text;
                final confirm = confirmCtrl.text;

                if (current.isEmpty || newPass.isEmpty) return;
                if (newPass != confirm) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Las contraseñas no coinciden'),
                    backgroundColor: AppColors.expense,
                  ));
                  return;
                }
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('La contraseña debe tener al menos 6 caracteres'),
                    backgroundColor: AppColors.expense,
                  ));
                  return;
                }

                Navigator.pop(ctx);
                final error = await ref
                    .read(profileActionsProvider.notifier)
                    .changePassword(current, newPass);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(error ?? 'Contraseña actualizada'),
                    backgroundColor:
                        error != null ? AppColors.expense : AppColors.income,
                  ));
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).logout();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.colors.textHint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.textSecondary, size: 22),
      title: Text(label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
      trailing: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
    );
  }
}
