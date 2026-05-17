import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final dashboardSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return {};

  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
  final to = DateTime(now.year, now.month + 1, 0).toIso8601String().split('T').first;

  final results = await Future.wait([
    api.get('/workspaces/$workspaceId/transactions/summary', params: {'from': from, 'to': to}),
    api.get('/workspaces/$workspaceId/accounts/summary'),
  ]);

  return {
    'summary': results[0].data,
    'accounts': results[1].data,
  };
});

final recentTransactionsProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];

  final res = await api.get(
    '/workspaces/$workspaceId/transactions',
    params: {'limit': '5', 'page': '1'},
  );
  return res.data['data'] as List;
});
