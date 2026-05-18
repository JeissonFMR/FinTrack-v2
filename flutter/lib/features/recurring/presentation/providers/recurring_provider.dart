import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

final recurringListProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];
  final res = await api.get('/workspaces/$workspaceId/recurring-transactions');
  return res.data as List;
});

class RecurringActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create(Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post('/workspaces/$workspaceId/recurring-transactions', data: data);
      ref.invalidate(recurringListProvider);
    });
  }

  Future<void> edit(String id, Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.patch('/workspaces/$workspaceId/recurring-transactions/$id',
          data: data);
      ref.invalidate(recurringListProvider);
    });
  }

  Future<void> delete(String id) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.delete('/workspaces/$workspaceId/recurring-transactions/$id');
      ref.invalidate(recurringListProvider);
    });
  }

  Future<void> runNow(String id) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post(
          '/workspaces/$workspaceId/recurring-transactions/$id/run-now');
      ref.invalidate(recurringListProvider);
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.read(transactionsPaginationProvider.notifier).refresh();
    });
  }
}

final recurringActionsProvider =
    AsyncNotifierProvider<RecurringActionsNotifier, void>(
        RecurringActionsNotifier.new);
