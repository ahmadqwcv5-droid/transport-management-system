import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/live_operations_models.dart';

final class LiveOperationsRepository {
  LiveOperationsRepository(this._client);
  final ApiClient _client;

  Future<NotificationPage> notifications() async {
    try {
      final response = await _client.dio.get<Json>(
        '/api/notifications',
        queryParameters: {'pageSize': 100},
      );
      return NotificationPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> markRead(String id) => _post('/api/notifications/$id/read');
  Future<void> markAllRead() => _post('/api/notifications/read-all');

  Future<DriverMyTrip> myTrip() async {
    try {
      final response = await _client.dio.get<Json>('/api/driver/my-trip');
      return DriverMyTrip.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<DriverWorkspace> workspace() async {
    try {
      final response = await _client.dio.get<Json>(
        '/api/driver/my-trip/workspace',
      );
      return DriverWorkspace.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> confirmLoaded() => _post('/api/driver/my-trip/confirm-loaded');
  Future<void> confirmDelivery() =>
      _post('/api/driver/my-trip/confirm-delivery');

  Future<void> _post(String path) async {
    try {
      await _client.dio.post<void>(path);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
