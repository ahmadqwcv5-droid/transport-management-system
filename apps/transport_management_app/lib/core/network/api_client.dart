import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';

typedef RefreshSession = Future<bool> Function();
typedef SessionExpired = Future<void> Function();

final class ApiClient {
  ApiClient(this._tokenStore)
    : dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final TokenStore _tokenStore;
  final Dio dio;
  RefreshSession? refreshSession;
  SessionExpired? sessionExpired;
  Completer<bool>? _refreshCompleter;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final accessToken = _tokenStore.accessToken;
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final canRetry = error.response?.statusCode == 401 &&
        request.extra['retried'] != true &&
        !request.path.endsWith('/api/auth/login') &&
        !request.path.endsWith('/api/auth/refresh');
    if (!canRetry || refreshSession == null) return handler.next(error);

    try {
      final refreshed = await _refreshOnce();
      if (!refreshed) {
        await sessionExpired?.call();
        return handler.next(error);
      }
      request.extra['retried'] = true;
      request.headers['Authorization'] = 'Bearer ${_tokenStore.accessToken}';
      final response = await dio.fetch<dynamic>(request);
      handler.resolve(response);
    } on Object {
      await sessionExpired?.call();
      handler.next(error);
    }
  }

  Future<bool> _refreshOnce() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      completer.complete(await refreshSession!.call());
      return await completer.future;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }
}
