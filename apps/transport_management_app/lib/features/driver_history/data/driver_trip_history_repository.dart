import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/driver_trip_history_models.dart';

final class DriverTripHistoryRepository {
  DriverTripHistoryRepository(this._client);
  final ApiClient _client;

  Future<DriverTripHistoryPage> query({
    required String category,
    required int page,
    int pageSize = 20,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _client.dio.get<Json>(
        '/api/driver/trips',
        queryParameters: {
          'category': category,
          'page': page,
          'pageSize': pageSize,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
      );
      return DriverTripHistoryPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<DriverTripHistoryDetail> detail(String tripId) async {
    try {
      final response = await _client.dio.get<Json>('/api/driver/trips/$tripId');
      return DriverTripHistoryDetail.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
