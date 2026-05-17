import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

/// Wrapper para manejar el permiso de "Acceso a notificaciones".
/// La captura real se hace en [BackgroundCaptureService], que corre en un
/// isolate de background con foreground service.
class BankNotificationListener {
  const BankNotificationListener();

  Future<bool> hasPermission() =>
      NotificationListenerService.isPermissionGranted();

  Future<bool> requestPermission() =>
      NotificationListenerService.requestPermission();
}

final bankNotificationListenerProvider = Provider<BankNotificationListener>(
  (_) => const BankNotificationListener(),
);

/// Modelo de transacción parseada por la IA a partir de una notificación.
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
