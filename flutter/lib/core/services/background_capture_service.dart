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
  // Bancos tradicionales
  'com.davivienda.davimovil',
  'co.com.bancolombia.appsiu',
  'com.bancolombia.personas',
  'com.bancodebogota.bdb',
  'com.bbva.bbvacontigo',
  'co.com.bancocajasocial.miBCS',
  'com.bancopopular.appersonas',
  'com.bancofalabella.bancofalabella',
  'com.scotiabankcolpatria.mibanco',
  'com.itau.app',
  'com.avvillas.movilbanking',
  'com.bancognbsudameris.appgnb',
  // Wallets digitales / fintechs
  'com.nequi.MobileApp',
  'com.nequi.mobile',
  'com.daviplata',
  'co.com.davivienda.daviplata',
  'com.rappi.pay',
  'co.com.movii.app',
  'com.tpaga.movil',
  'com.lulobank.android',
  'com.coink',
  // DEV: descomentar para probar con `adb shell cmd notification post`
  // 'com.android.shell',
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

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'FinanzasJM',
      content: 'Detectando transacciones automáticamente',
    );
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  NotificationListenerService.notificationsStream.listen(
    (event) => _handleNotification(event, service),
    onError: (Object _) {},
    cancelOnError: false,
  );
}

Future<void> _handleNotification(
  ServiceNotificationEvent event,
  ServiceInstance service,
) async {
  final pkg = event.packageName ?? '';
  final title = event.title ?? '';
  final content = event.content ?? '';

  if (pkg == 'com.example.finanzasjm') return;
  if (!_bankPackages.contains(pkg)) return;
  if (content.isEmpty) return;

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
    if (token == null || workspaceId == null) return;

    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

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
    if (data['isTransaction'] != true) return;
    final amount = data['amount'];
    if (amount == null || (amount as num) <= 0) return;

    // Decidir auto-registro vs sheet de confirmación
    final autoEnabled = prefs.getBool('auto_register_enabled') ?? true;
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0;
    final hasAccount = data['accountId'] != null;
    final hasCategory = data['categoryId'] != null;
    final hasType = data['type'] != null;
    final canAutoRegister =
        autoEnabled && confidence >= 0.85 && hasAccount && hasCategory && hasType;

    final merchant = data['merchant'] as String? ?? 'sin comercio';
    final bank = data['bank'] as String? ?? '';
    final amountStr = _formatAmount(amount.toDouble());
    final bankPrefix = bank.isNotEmpty ? '$bank · ' : '';

    if (canAutoRegister) {
      try {
        await dio.post('/workspaces/$workspaceId/transactions', data: {
          'accountId': data['accountId'],
          'categoryId': data['categoryId'],
          'type': data['type'],
          'amount': amount,
          'description': merchant,
          'date': (data['date'] as String?) ??
              DateTime.now().toIso8601String().split('T').first,
        });

        final plugin = FlutterLocalNotificationsPlugin();
        await plugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          '✅ Transacción registrada',
          '$bankPrefix\$$amountStr en $merchant — toca para editar',
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
        return;
      } catch (_) {
        // Fallback al flujo de confirmación manual abajo
      }
    }

    // Flujo normal: guardar como pendiente y notificar para confirmación
    final pending = prefs.getStringList(_pendingDetectionsKey) ?? [];
    pending.add(jsonEncode(data));
    await prefs.setStringList(_pendingDetectionsKey, pending);

    service.invoke('newDetection', data);

    final plugin = FlutterLocalNotificationsPlugin();
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
  } catch (_) {
    // Silenciamos errores de red/token — el listener no debe romper.
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
