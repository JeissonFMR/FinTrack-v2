import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final budgetsProvider = FutureProvider<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];
  final res = await api.get('/workspaces/$workspaceId/budgets');
  return res.data as List;
});
