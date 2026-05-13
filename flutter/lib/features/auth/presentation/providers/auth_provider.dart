import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

final authStateProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(tokenStorageProvider);
  final token = await storage.getAccessToken();
  return token != null;
});

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login(String email, String password) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await api.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      await storage.saveTokens(
        accessToken: res.data['accessToken'],
        refreshToken: res.data['refreshToken'],
      );
      await _saveWorkspace();
      ref.invalidate(authStateProvider);
    });
  }

  Future<void> register(String name, String email, String password) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await api.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });
      await storage.saveTokens(
        accessToken: res.data['accessToken'],
        refreshToken: res.data['refreshToken'],
      );
      await _saveWorkspace();
      ref.invalidate(authStateProvider);
    });
  }

  Future<void> logout() async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final refresh = await storage.getRefreshToken();
    if (refresh != null) {
      await api.post('/auth/logout', data: {'refreshToken': refresh});
    }
    await storage.clear();
    ref.invalidate(authStateProvider);
  }

  Future<void> _saveWorkspace() async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final res = await api.get('/workspaces');
    final workspaces = res.data as List;
    if (workspaces.isNotEmpty) {
      await storage.saveWorkspaceId(workspaces.first['id']);
    }
  }
}
