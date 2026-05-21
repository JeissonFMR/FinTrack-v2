import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/biometric_service.dart';
import '../providers/auth_provider.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _attempting = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Disparar la huella automáticamente al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_attempting) return;
    setState(() {
      _attempting = true;
      _failed = false;
    });

    final ok = await BiometricService.instance.authenticate();

    if (!mounted) return;
    if (ok) {
      // Marcar la sesión como desbloqueada y navegar al dashboard
      ref.read(sessionUnlockedProvider.notifier).state = true;
      context.go('/dashboard');
    } else {
      setState(() {
        _attempting = false;
        _failed = true;
      });
    }
  }

  Future<void> _useLogin() async {
    // Si el usuario prefiere usar email/contraseña, cerramos sesión
    await ref.read(authNotifierProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint,
                    size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              const Text(
                'FinanzasJM',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _failed
                    ? 'No se pudo verificar — toca para intentar de nuevo'
                    : 'Confirma tu identidad para continuar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _failed
                      ? AppColors.expense
                      : context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _attempting ? null : _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: Text(_attempting ? 'Verificando...' : 'Usar huella'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _useLogin,
                child: const Text('Iniciar sesión con email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indica si la sesión ya está desbloqueada (después del prompt biométrico).
/// Si el usuario tiene biométrico activado y aún no se autenticó, el router
/// debe redirigirlo a la pantalla de lock.
final sessionUnlockedProvider = StateProvider<bool>((_) => false);
