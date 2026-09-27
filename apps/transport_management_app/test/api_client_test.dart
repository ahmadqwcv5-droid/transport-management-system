import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/core/network/api_client.dart';
import 'package:transport_management_app/core/storage/token_store.dart';

void main() {
  test('concurrent stale 401 responses share one rotated session', () async {
    final tokenStore = TokenStore()..setAccessToken('old-access');
    final client = ApiClient(tokenStore);
    final adapter = _RefreshRaceAdapter();
    client.dio.httpClientAdapter = adapter;
    var refreshCalls = 0;
    var expirationCalls = 0;
    client.refreshSession = () async {
      refreshCalls++;
      tokenStore.setAccessToken('new-access');
      adapter.refreshCompleted.complete();
      return true;
    };
    client.sessionExpired = () async => expirationCalls++;

    final responses = await Future.wait([
      client.dio.get<Map<String, dynamic>>('/first'),
      client.dio.get<Map<String, dynamic>>('/second'),
    ]);

    expect(responses.map((response) => response.statusCode), everyElement(200));
    expect(refreshCalls, 1);
    expect(expirationCalls, 0);
    expect(adapter.oldTokenRequests, 2);
    expect(adapter.newTokenRequests, 2);
  });
}

final class _RefreshRaceAdapter implements HttpClientAdapter {
  final Completer<void> _bothOldRequestsStarted = Completer<void>();
  final Completer<void> refreshCompleted = Completer<void>();
  int oldTokenRequests = 0;
  int newTokenRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final authorization = options.headers['Authorization'];
    if (authorization == 'Bearer new-access') {
      newTokenRequests++;
      return _jsonResponse(200, {'path': options.path});
    }

    expect(authorization, 'Bearer old-access');
    oldTokenRequests++;
    if (oldTokenRequests == 1) {
      await _bothOldRequestsStarted.future;
    } else {
      if (!_bothOldRequestsStarted.isCompleted) {
        _bothOldRequestsStarted.complete();
      }
      await refreshCompleted.future;
    }
    return _jsonResponse(401, {
      'code': 'UNAUTHORIZED',
      'message': 'Expired access token',
    });
  }

  ResponseBody _jsonResponse(int statusCode, Object body) =>
      ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}
