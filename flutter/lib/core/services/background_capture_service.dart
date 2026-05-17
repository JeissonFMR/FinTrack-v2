import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bgServiceChannelId = 'finanzasjm_background_service';
const _bgServiceNotifId = 9001;
const _detectedChannelId = 'detected_transactions';
const _pendingDetectionsKey = 'pending_detections';
const _processedHashesKey = 'bank_notif_processed';
const _notificationsEnabledKey = 'notifications_enabled';

const _bankPackages = <String>{
  'com.davivienda.davimovil',
  'com.todo1.mobile',
  'com.bancolombia.alkosto',
  'com.nequi.MobileApp',
  'com.nequi.mobile',
  'com.daviplata',
  'co.com.bancolombia.appperonal',
  'com.bbva.netcash',
  'com.bbva.bbvacontigo',
  'com.scotiabankcolpatria.mibanco',
  'com.tpaga.movil',
  'co.com.movii.app',
  'com.android.shell', // DEV ONLY
};

const _baseUrl = 'http://10.0.2.2:3000/api/v1';

class BackgroundCaptureService {
  BackgroundCaptureService._();

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: _bgServiceChannelId,
        initialNotificationTitle: 'FinanzasJM',
        initialNotificationContent:
            'Detectando transacciones automáticamente',
        foregroundServiceNotificationId: _bgServiceNotifId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );

    // Crear el canal de la notif persistente (Android 8+)
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _bgServiceChannelId,
          'Servicio de detección',
          description: 'Mantiene activa la captura de notificaciones bancarias',
          importance: Importance.low,
        ));
  }

  static Future<bool> start() async {
    final service = FlutterBackgroundService();
    return service.startService();
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return service.isRunning();
  }

  /// Stream de eventos `newDetection` emitidos desde el background isolate
  static Stream<Map<String, dynamic>?> get detections =>
      FlutterBackgroundService().on('newDetection');
}

// Lee las detecciones que el isolate de background dejó guardadas
Future<List<Map<String, dynamic>>> readPendingDetections() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_pendingDetectionsKey) ?? const [];
  return raw
      .map((s) {
        try {
          return Map<String, dynamic>.from(jsonDecode(s) as Map);
        } catch (_) {
          return <String, dynamic>{};
        }
      })
      .where((m) => m.isNotEmpty)
      .toList();
}

Future<void> clearPendingDetections() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_pendingDetectionsKey);
}

// ===================== ISOLATE DE BACKGROUND =====================

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // ignore: avoid_print
  print('[BgCapture] 🚀 onStart ejecutado en isolate de background');

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'FinanzasJM',
      content: 'Detectando transacciones automáticamente',
    );
    // ignore: avoid_print
    print('[BgCapture] Foreground service configurado');
  }

  service.on('stopService').listen((_) {
    // ignore: avoid_print
    print('[BgCapture] Stop service recibido');
    service.stopSelf();
  });

  // Suscripción persistente al stream de notificaciones del sistema
  final sub = NotificationListenerService.notificationsStream.listen(
    (event) {
      // ignore: avoid_print
      print(
          '[BgCapture] 🔔 Evento recibido pkg=${event.packageName} title="${event.title}"');
      _handleNotification(event, service);
    },
    onError: (Object e) {
      // ignore: avoid_print
      print('[BgCapture] ❌ Error en stream: $e');
    },
    cancelOnError: false,
  );

  // ignore: avoid_print
  print('[BgCapture] ✅ Subscripción a notificaciones registrada: $sub');
}

Future<void> _handleNotification(
  ServiceNotificationEvent event,
  ServiceInstance service,
) async {
  final pkg = event.packageName ?? '';
  final title = event.title ?? '';
  final content = event.content ?? '';

  if (pkg == 'com.example.finanzasjm') {
    // ignore: avoid_print
    print('[BgCapture] auto-eco ignorado');
    return;
  }
  if (!_bankPackages.contains(pkg)) {
    // ignore: avoid_print
    print('[BgCapture] pkg=$pkg no es banco — ignorado');
    return;
  }
  if (content.isEmpty) {
    // ignore: avoid_print
    print('[BgCapture] body vacío — ignorado');
    return;
  }
  // ignore: avoid_print
  print('[BgCapture] ✓ Pasó filtro de banco, procesando: $content');

  // Verificar flag de habilitado
  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool(_notificationsEnabledKey) ?? true;
  if (!enabled) return;

  // Deduplicación
  final hash = '$pkg|$title|$content'.hashCode.toString();
  final seen = prefs.getStringList(_processedHashesKey) ?? [];
  if (seen.contains(hash)) return;
  seen.add(hash);
  if (seen.length > 200) seen.removeRange(0, seen.length - 200);
  await prefs.setStringList(_processedHashesKey, seen);

  // Llamar al backend con el token guardado
  try {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    final workspaceId = await storage.read(key: 'workspace_id');
    // ignore: avoid_print
    print(
        '[BgCapture] token=${token == null ? 'null' : 'OK(${token.length})'} workspace=$workspaceId');
    if (token == null || workspaceId == null) {
      // ignore: avoid_print
      print('[BgCapture] ⚠️ Faltan credenciales — abortando');
      return;
    }

    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // ignore: avoid_print
    print('[BgCapture] → Enviando al backend...');
    final res = await dio.post(
      '/workspaces/$workspaceId/transactions/parse-notification',
      data: {
        'packageName': pkg,
        'title': title,
        'content': content,
        'postedAt': DateTime.now().toIso8601String(),
      },
    );

    final data = Map<String, dynamic>.from(res.data as Map);
    // ignore: avoid_print
    print('[BgCapture] ← Backend respondió: $data');
    if (data['isTransaction'] != true) {
      // ignore: avoid_print
      print('[BgCapture] isTransaction=false, descartando');
      return;
    }
    final amount = data['amount'];
    if (amount == null || (amount as num) <= 0) {
      // ignore: avoid_print
      print('[BgCapture] amount inválido: $amount');
      return;
    }

    // Guardar como pendiente para que la UI lo muestre cuando se abra
    final pending = prefs.getStringList(_pendingDetectionsKey) ?? [];
    pending.add(jsonEncode(data));
    await prefs.setStringList(_pendingDetectionsKey, pending);

    // Emitir evento al main isolate si está vivo
    service.invoke('newDetection', data);

    // Mostrar notificación local "toca para confirmar"
    final plugin = FlutterLocalNotificationsPlugin();
    final merchant = data['merchant'] as String? ?? 'sin comercio';
    final bank = data['bank'] as String? ?? '';
    final amountStr = _formatAmount(amount.toDouble());
    final bankPrefix = bank.isNotEmpty ? '$bank · ' : '';
    await plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Nueva transacción detectada',
      '$bankPrefix\$$amountStr en $merchant — toca para confirmar',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _detectedChannelId,
          'Transacciones detectadas',
          channelDescription: 'Detectadas desde notificaciones bancarias',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  } catch (e, st) {
    // ignore: avoid_print
    print('[BgCapture] ❌ Error procesando: $e\n$st');
  }
}

String _formatAmount(double n) {
  final s = n.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}
