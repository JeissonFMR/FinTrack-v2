import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

class TokenStorage {
  final _storage = const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _workspaceKey = 'workspace_id';

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);
  Future<String?> getWorkspaceId() => _storage.read(key: _workspaceKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
    ]);
  }

  Future<void> saveWorkspaceId(String id) =>
      _storage.write(key: _workspaceKey, value: id);

  Future<void> clear() => _storage.deleteAll();
}
