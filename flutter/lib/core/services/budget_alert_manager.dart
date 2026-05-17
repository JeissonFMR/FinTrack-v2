import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../storage/token_storage.dart';
import 'notification_service.dart';
import 'notifications_pref.dart';

/// Verifica los presupuestos tras un cambio en transacciones y dispara
/// notificaciones cuando se cruza el umbral o se excede el 100%.
class BudgetAlertManager {
  BudgetAlertManager(this._ref);

  final Ref _ref;

  Future<void> checkBudgets() async {
    if (!_ref.read(notificationsEnabledProvider)) return;
    try {
      final api = _ref.read(apiClientProvider);
      final storage = _ref.read(tokenStorageProvider);
      final workspaceId = await storage.getWorkspaceId();
      if (workspaceId == null) return;

      final res = await api.get('/workspaces/$workspaceId/budgets');
      final budgets = res.data as List;

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final periodKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      for (final b in budgets) {
        final id = b['id'] as String;
        final percentage = _toDouble(b['percentage']).toInt();
        final alertAt = (b['alertAt'] as num?)?.toInt() ?? 80;
        final categoryName = (b['category'] as Map?)?['name'] as String? ?? 'Categoría';
        final spent = _toDouble(b['spent']);
        final total = _toDouble(b['amount']);

        final key = 'budget_alert_${id}_$periodKey';
        final lastLevel = prefs.getInt(key) ?? 0;

        // Nivel 2: excedido (>= 100%)
        if (percentage >= 100 && lastLevel < 2) {
          await NotificationService.instance.showBudgetAlert(
            categoryName: categoryName,
            percentage: percentage,
            spent: spent,
            total: total,
          );
          await prefs.setInt(key, 2);
          continue;
        }

        // Nivel 1: cruce de umbral configurado
        if (percentage >= alertAt && lastLevel < 1) {
          await NotificationService.instance.showBudgetAlert(
            categoryName: categoryName,
            percentage: percentage,
            spent: spent,
            total: total,
          );
          await prefs.setInt(key, 1);
        }
      }
    } catch (_) {
      // Las notificaciones nunca deben bloquear el flujo de transacciones
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

final budgetAlertManagerProvider =
    Provider<BudgetAlertManager>((ref) => BudgetAlertManager(ref));
