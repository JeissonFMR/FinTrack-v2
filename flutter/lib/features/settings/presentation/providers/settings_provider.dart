import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final settingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final storage = ref.read(tokenStorageProvider);
  final api = ref.read(apiClientProvider);

  String? email;
  String? workspaceId;
  String? workspaceName;

  final token = await storage.getAccessToken();
  if (token != null) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        var payload = parts[1];
        final remainder = payload.length % 4;
        if (remainder != 0) payload = payload.padRight(payload.length + (4 - remainder), '=');
        final decoded = utf8.decode(base64Url.decode(payload));
        final map = jsonDecode(decoded) as Map;
        email = map['email'] as String?;
      }
    } catch (_) {}
  }

  try {
    final res = await api.get('/workspaces');
    final workspaces = res.data as List;
    if (workspaces.isNotEmpty) {
      workspaceName = workspaces.first['name'] as String?;
      workspaceId = workspaces.first['id'] as String?;
    }
  } catch (_) {}

  return {'email': email, 'workspaceName': workspaceName, 'workspaceId': workspaceId};
});

class ProfileActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> updateWorkspaceName(String workspaceId, String name) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.patch('/workspaces/$workspaceId', data: {'name': name});
      ref.invalidate(settingsProvider);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.patch('/auth/me/password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      return null;
    } catch (e) {
      return 'Contraseña actual incorrecta';
    }
  }
}

final profileActionsProvider =
    AsyncNotifierProvider<ProfileActionsNotifier, void>(ProfileActionsNotifier.new);
