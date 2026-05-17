import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../storage/token_storage.dart';
import 'notification_service.dart';
import 'notifications_pref.dart';

/// Paquetes de apps bancarias/fintech soportadas. La detección final
/// la hace el LLM, esto es solo un primer filtro para no enviar TODA
/// notificación al backend.
const _bankPackages = <String>{
  'com.davivienda.davimovil',
  'com.todo1.mobile', // Bancolombia
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
  // DEV ONLY: permite probar con `adb shell cmd notification post`
  'com.android.shell',
};

/// Almacena en SharedPreferences las notificaciones ya procesadas (hash) para
/// evitar duplicados (Android puede entregarlas más de una vez).
const _processedKey = 'bank_notif_processed';

class BankNotificationListener {
  BankNotificationListener(this._ref);

  final Ref _ref;
  StreamSubscription<ServiceNotificationEvent>? _sub;

  /// Stream de transacciones parseadas listas para confirmar.
  final _detectedController = StreamController<ParsedBankTransaction>.broadcast();
  Stream<ParsedBankTransaction> get detected => _detectedController.stream;

  Future<bool> hasPermission() => NotificationListenerService.isPermissionGranted();

  Future<bool> requestPermission() =>
      NotificationListenerService.requestPermission();

  Future<void> start() async {
    if (_sub != null) {
      // ignore: avoid_print
      print('[BankListener] start() llamado pero ya estaba activo');
      return;
    }
    final granted = await hasPermission();
    // ignore: avoid_print
    print('[BankListener] start() → permiso=$granted');
    if (!granted) return;

    _sub = NotificationListenerService.notificationsStream.listen(_onEvent);
    // ignore: avoid_print
    print('[BankListener] Suscrito al stream de notificaciones');
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onEvent(ServiceNotificationEvent event) async {
    final pkg = event.packageName ?? '';
    final title = event.title ?? '';
    final content = event.content ?? '';

    // Ignorar nuestras propias notificaciones para no entrar en bucle de logs
    if (pkg == 'com.example.finanzasjm') return;

    // ignore: avoid_print
    print('[BankListener] 🔔 Notif recibida pkg=$pkg title="$title" body="$content"');

    if (!_ref.read(notificationsEnabledProvider)) {
      // ignore: avoid_print
      print('[BankListener] Notificaciones deshabilitadas en config — ignorada');
      return;
    }

    if (!_bankPackages.contains(pkg)) {
      // ignore: avoid_print
      print('[BankListener] pkg=$pkg no está en la lista — ignorada');
      return;
    }

    if (content.isEmpty) {
      // ignore: avoid_print
      print('[BankListener] body vacío — ignorada');
      return;
    }

    // Hash simple para deduplicar
    final hash = '$pkg|$title|$content'.hashCode.toString();
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_processedKey) ?? [];
    if (seen.contains(hash)) return;
    seen.add(hash);
    // Mantener solo los últimos 200
    if (seen.length > 200) seen.removeRange(0, seen.length - 200);
    await prefs.setStringList(_processedKey, seen);

    try {
      final api = _ref.read(apiClientProvider);
      final storage = _ref.read(tokenStorageProvider);
      final workspaceId = await storage.getWorkspaceId();
      // ignore: avoid_print
      print('[BankListener] workspaceId=$workspaceId');
      if (workspaceId == null) {
        // ignore: avoid_print
        print('[BankListener] ⚠️ NO HAY WORKSPACE GUARDADO — abortando');
        return;
      }

      // ignore: avoid_print
      print('[BankListener] → Enviando al backend...');
      final res = await api.post(
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
      print('[BankListener] ← Backend respondió: $data');
      final parsed = ParsedBankTransaction.fromJson(data);

      if (!parsed.isTransaction || parsed.amount == null || parsed.amount! <= 0) {
        // ignore: avoid_print
        print('[BankListener] No es transacción válida — descartada');
        return;
      }

      // ignore: avoid_print
      print('[BankListener] ✅ Transacción detectada — emitiendo al stream');
      _detectedController.add(parsed);

      // Notificación local para que el usuario abra la app
      await NotificationService.instance.showDetectedTransactionAlert(
        amount: parsed.amount!,
        merchant: parsed.merchant ?? 'sin comercio',
        bank: parsed.bank ?? '',
      );

      // Guardar la última detectada en prefs para que la UI la lea al abrir
      await prefs.setString('last_detected_tx', jsonEncode(data));
    } catch (e, st) {
      // ignore: avoid_print
      print('[BankListener] ❌ Error: $e\n$st');
    }
  }
}

class ParsedBankTransaction {
  final bool isTransaction;
  final String? type;
  final double? amount;
  final String? merchant;
  final String? bank;
  final String? date;
  final String? cardLast4;
  final String? description;
  final String? categoryId;
  final String? accountId;
  final double confidence;

  const ParsedBankTransaction({
    required this.isTransaction,
    this.type,
    this.amount,
    this.merchant,
    this.bank,
    this.date,
    this.cardLast4,
    this.description,
    this.categoryId,
    this.accountId,
    this.confidence = 0,
  });

  factory ParsedBankTransaction.fromJson(Map<String, dynamic> json) {
    double? amt;
    final raw = json['amount'];
    if (raw is num) amt = raw.toDouble();
    if (raw is String) amt = double.tryParse(raw);

    return ParsedBankTransaction(
      isTransaction: json['isTransaction'] == true,
      type: json['type'] as String?,
      amount: amt,
      merchant: json['merchant'] as String?,
      bank: json['bank'] as String?,
      date: json['date'] as String?,
      cardLast4: json['cardLast4'] as String?,
      description: json['description'] as String?,
      categoryId: json['categoryId'] as String?,
      accountId: json['accountId'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'isTransaction': isTransaction,
        'type': type,
        'amount': amount,
        'merchant': merchant,
        'bank': bank,
        'date': date,
        'cardLast4': cardLast4,
        'description': description,
        'categoryId': categoryId,
        'accountId': accountId,
        'confidence': confidence,
      };
}

final bankNotificationListenerProvider = Provider<BankNotificationListener>(
  (ref) => BankNotificationListener(ref),
);
