import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final budgetsProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];
  final res = await api.get('/workspaces/$workspaceId/budgets');
  return res.data as List;
});

class BudgetActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create(Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post('/workspaces/$workspaceId/budgets', data: data);
      ref.invalidate(budgetsProvider);
    });
  }

  Future<void> edit(String budgetId, Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.patch('/workspaces/$workspaceId/budgets/$budgetId', data: data);
      ref.invalidate(budgetsProvider);
    });
  }

  Future<void> delete(String budgetId) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.delete('/workspaces/$workspaceId/budgets/$budgetId');
      ref.invalidate(budgetsProvider);
    });
  }
}

final budgetActionsProvider =
    AsyncNotifierProvider<BudgetActionsNotifier, void>(BudgetActionsNotifier.new);
