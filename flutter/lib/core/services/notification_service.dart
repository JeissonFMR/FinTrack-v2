import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _budgetChannelId = 'budget_alerts';
  static const _debtChannelId = 'debt_alerts';
  static const _detectedChannelId = 'detected_transactions';

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _budgetChannelId,
          'Alertas de presupuesto',
          description: 'Avisos cuando un presupuesto se acerca al límite',
          importance: Importance.high,
        ));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _debtChannelId,
          'Recordatorios de deudas',
          description: 'Avisos antes del vencimiento de deudas',
          importance: Importance.high,
        ));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _detectedChannelId,
          'Transacciones detectadas',
          description: 'Detectadas desde notificaciones bancarias',
          importance: Importance.high,
        ));

    _initialized = true;
  }

  Future<void> showDetectedTransactionAlert({
    required double amount,
    required String merchant,
    required String bank,
  }) async {
    await init();
    final bankPrefix = bank.isNotEmpty ? '$bank · ' : '';
    await _plugin.show(
      _hash('detected_${DateTime.now().millisecondsSinceEpoch}'),
      'Nueva transacción detectada',
      '$bankPrefix\$${_fmt(amount)} en $merchant — toca para confirmar',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _detectedChannelId,
          'Transacciones detectadas',
          channelDescription: 'Detectadas desde notificaciones bancarias',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<bool> requestPermissions() async {
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    return androidGranted && iosGranted;
  }

  Future<void> showBudgetAlert({
    required String categoryName,
    required int percentage,
    required double spent,
    required double total,
  }) async {
    await init();

    final isOver = percentage >= 100;
    final title = isOver
        ? 'Presupuesto excedido: $categoryName'
        : 'Presupuesto al $percentage% — $categoryName';
    final body = isOver
        ? 'Has gastado \$${_fmt(spent)} de \$${_fmt(total)}'
        : 'Llevas \$${_fmt(spent)} de \$${_fmt(total)}';

    await _plugin.show(
      _hash('budget_$categoryName'),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _budgetChannelId,
          'Alertas de presupuesto',
          channelDescription: 'Avisos cuando un presupuesto se acerca al límite',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> scheduleDebtReminder({
    required String debtId,
    required String debtName,
    required DateTime dueDate,
    required double remainingAmount,
  }) async {
    await init();

    // Cancelar recordatorio previo de esta deuda
    await cancelDebtReminder(debtId);

    // Programar un día antes a las 9:00 AM
    final reminder = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9,
    ).subtract(const Duration(days: 1));

    // Si ya pasó la fecha de recordatorio, no programar
    if (reminder.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      _hash('debt_$debtId'),
      'Deuda próxima a vencer: $debtName',
      'Vence mañana — pendiente \$${_fmt(remainingAmount)}',
      tz.TZDateTime.from(reminder, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _debtChannelId,
          'Recordatorios de deudas',
          channelDescription: 'Avisos antes del vencimiento de deudas',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelDebtReminder(String debtId) async {
    await _plugin.cancel(_hash('debt_$debtId'));
  }

  int _hash(String s) => s.hashCode & 0x7fffffff;

  String _fmt(double n) {
    final str = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}
