import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final transactionsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return {'data': [], 'meta': {}};

  final res = await api.get(
    '/workspaces/$workspaceId/transactions',
    params: {'limit': '50', 'page': '1'},
  );
  return Map<String, dynamic>.from(res.data);
});

final categoriesProvider = FutureProvider<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];
  final res = await api.get('/workspaces/$workspaceId/categories');
  return res.data as List;
});

final accountsListProvider = FutureProvider<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];
  final res = await api.get('/workspaces/$workspaceId/accounts');
  return res.data as List;
});
