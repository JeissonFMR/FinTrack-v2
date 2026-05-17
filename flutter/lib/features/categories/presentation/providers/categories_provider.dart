import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

class CategoryActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.post('/workspaces/$workspaceId/categories', data: {
        'name': name,
        'type': type,
        'icon': icon,
        'color': color,
      });
      ref.invalidate(categoriesProvider);
    });
  }

  Future<void> edit(String categoryId, Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.patch('/workspaces/$workspaceId/categories/$categoryId', data: data);
      ref.invalidate(categoriesProvider);
    });
  }

  Future<void> delete(String categoryId) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.delete('/workspaces/$workspaceId/categories/$categoryId');
      ref.invalidate(categoriesProvider);
    });
  }
}

final categoryActionsProvider =
    AsyncNotifierProvider<CategoryActionsNotifier, void>(CategoryActionsNotifier.new);
