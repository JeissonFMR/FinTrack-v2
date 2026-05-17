import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final goalsProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];
  final res = await api.get('/workspaces/$workspaceId/goals');
  return res.data as List;
});

class GoalActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({
    required String name,
    required double targetAmount,
    double? initialAmount,
    String? deadline,
    required String color,
  }) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post('/workspaces/$workspaceId/goals', data: {
        'name': name,
        'targetAmount': targetAmount,
        if (initialAmount != null && initialAmount > 0) 'initialAmount': initialAmount,
        'deadline': ?deadline,
        'color': color,
      });
      ref.invalidate(goalsProvider);
    });
  }

  Future<void> delete(String goalId) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.delete('/workspaces/$workspaceId/goals/$goalId');
      ref.invalidate(goalsProvider);
    });
  }

  Future<void> edit(String goalId, Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.patch('/workspaces/$workspaceId/goals/$goalId', data: data);
      ref.invalidate(goalsProvider);
    });
  }

  Future<void> addProgress(String goalId, double amount) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post('/workspaces/$workspaceId/goals/$goalId/progress',
          data: {'amount': amount});
      ref.invalidate(goalsProvider);
    });
  }
}

final goalActionsProvider =
    AsyncNotifierProvider<GoalActionsNotifier, void>(GoalActionsNotifier.new);
