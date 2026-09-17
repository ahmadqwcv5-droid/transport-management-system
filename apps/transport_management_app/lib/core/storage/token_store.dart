import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access tokens live only in memory. The longer-lived refresh token uses the
/// platform secure store (Android Keystore and WebCrypto-backed web storage).
final class TokenStore {
  TokenStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _refreshKey = 'tms_refresh_token';
  final FlutterSecureStorage _secureStorage;
  String? _accessToken;

  String? get accessToken => _accessToken;
  void setAccessToken(String value) => _accessToken = value;
  Future<String?> readRefreshToken() => _secureStorage.read(key: _refreshKey);
  Future<void> setRefreshToken(String value) =>
      _secureStorage.write(key: _refreshKey, value: value);

  Future<void> clear() async {
    _accessToken = null;
    await _secureStorage.delete(key: _refreshKey);
  }
}
