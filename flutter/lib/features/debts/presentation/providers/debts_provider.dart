import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final debtsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return {'debts': [], 'iOwe': 0, 'owedToMe': 0, 'netDebt': 0};
  final res = await api.get('/workspaces/$workspaceId/debts/summary');
  return Map<String, dynamic>.from(res.data);
});

class DebtActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({
    required String name,
    required String type,
    required double totalAmount,
    String? contactName,
    String? dueDate,
    String? notes,
  }) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post('/workspaces/$workspaceId/debts', data: {
        'name': name,
        'type': type,
        'totalAmount': totalAmount,
        'contactName': contactName,
        'dueDate': dueDate,
        'notes': notes,
      });
      ref.invalidate(debtsProvider);
    });
  }

  Future<void> recordPayment(String debtId, double amount) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post('/workspaces/$workspaceId/debts/$debtId/payment',
          data: {'amount': amount});
      ref.invalidate(debtsProvider);
    });
  }
}

final debtActionsProvider =
    AsyncNotifierProvider<DebtActionsNotifier, void>(DebtActionsNotifier.new);
