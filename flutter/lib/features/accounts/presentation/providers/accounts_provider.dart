import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

final accountsSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return {'accounts': [], 'totalBalance': 0};
  final res = await api.get('/workspaces/$workspaceId/accounts/summary');
  return Map<String, dynamic>.from(res.data);
});

class CreateAccountNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({
    required String name,
    required String type,
    required double initialBalance,
    required String color,
    required String icon,
    String? cardLast4,
  }) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post('/workspaces/$workspaceId/accounts', data: {
        'name': name,
        'type': type,
        'initialBalance': initialBalance,
        'color': color,
        'icon': icon,
        'cardLast4': ?cardLast4,
      });
      ref.invalidate(accountsListProvider);
      ref.invalidate(accountsSummaryProvider);
    });
  }
}

final createAccountProvider =
    AsyncNotifierProvider<CreateAccountNotifier, void>(CreateAccountNotifier.new);

class AccountActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> edit(String accountId, Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.patch('/workspaces/$workspaceId/accounts/$accountId', data: data);
      ref.invalidate(accountsSummaryProvider);
      ref.invalidate(accountsListProvider);
    });
  }

  Future<void> archive(String accountId) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.delete('/workspaces/$workspaceId/accounts/$accountId');
      ref.invalidate(accountsSummaryProvider);
      ref.invalidate(accountsListProvider);
    });
  }
}

final accountActionsProvider =
    AsyncNotifierProvider<AccountActionsNotifier, void>(AccountActionsNotifier.new);
