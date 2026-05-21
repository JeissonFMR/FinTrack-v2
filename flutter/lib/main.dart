import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/background_capture_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  // Inicialización no-bloqueante de servicios opcionales.
  // Si alguno falla, la app debe arrancar igual.
  unawaited(_initOptionalServices());

  runApp(const ProviderScope(child: FinanzasApp()));
}

Future<void> _initOptionalServices() async {
  try {
    await NotificationService.instance.init();
    await NotificationService.instance.requestPermissions();
  } catch (_) {
    // No queremos bloquear arranque por permisos de notificación
  }
  try {
    await BackgroundCaptureService.initialize();
  } catch (_) {
    // El background service es opcional — si falla, la app sigue funcionando
  }
}

class FinanzasApp extends ConsumerWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'FinanzasJM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
