import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_session.dart';

final class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStore) {
    _apiClient.refreshSession = refresh;
  }

  final ApiClient _apiClient;
  final TokenStore _tokenStore;

  Future<AuthSession?> restore() async {
    if (await _tokenStore.readRefreshToken() == null) return null;
    return await refresh() ? currentSession() : null;
  }

  Future<AuthSession> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      return await _saveResponse(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<bool> refresh() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response =
          await Dio(
            BaseOptions(baseUrl: _apiClient.dio.options.baseUrl),
          ).post<Map<String, dynamic>>(
            '/api/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
      await _saveResponse(response.data!);
      return true;
    } on DioException {
      await _tokenStore.clear();
      return false;
    }
  }

  Future<AuthSession> currentSession() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/auth/me',
      );
      return AuthSession(user: CurrentUser.fromJson(response.data!));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    try {
      await _apiClient.dio.post<void>(
        '/api/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } finally {
      await _tokenStore.clear();
    }
  }

  Future<AuthSession> updateLocale(String locale) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/api/auth/me/preferences',
        data: {'preferredLocale': locale},
      );
      return AuthSession(user: CurrentUser.fromJson(response.data!));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AuthSession> updateNotificationSounds(bool enabled) async {
    try {
      final response = await _apiClient.dio.put<Map<String, dynamic>>(
        '/api/auth/me/notification-sounds',
        data: {'enabled': enabled},
      );
      return AuthSession(user: CurrentUser.fromJson(response.data!));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AuthSession> _saveResponse(Map<String, dynamic> data) async {
    _tokenStore.setAccessToken(data['accessToken'] as String);
    await _tokenStore.setRefreshToken(data['refreshToken'] as String);
    return AuthSession(
      user: CurrentUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }
}
