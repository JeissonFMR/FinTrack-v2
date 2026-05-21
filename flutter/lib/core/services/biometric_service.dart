import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBiometricEnabledKey = 'biometric_enabled';

class BiometricService {
  BiometricService._();
  static final instance = BiometricService._();

  final _auth = LocalAuthentication();

  /// ¿El dispositivo tiene hardware biométrico configurado?
  Future<bool> isDeviceSupported() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// ¿El usuario activó el biométrico en la app?
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabledKey, enabled);
  }

  /// Pide al usuario autenticarse con huella/face.
  Future<bool> authenticate({
    String reason = 'Confirma tu identidad para abrir FinanzasJM',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // permite PIN/patrón como fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricEnabledProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return BiometricService.instance.isEnabled();
});

final biometricSupportedProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return BiometricService.instance.isDeviceSupported();
});
