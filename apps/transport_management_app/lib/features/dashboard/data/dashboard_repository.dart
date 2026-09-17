import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/dashboard_models.dart';

final class DashboardRepository {
  DashboardRepository(this._client);
  final ApiClient _client;
  Future<DashboardData> load() async {
    try {
      final response = await _client.dio.get<Json>('/api/dashboard');
      return DashboardData.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> simulator(
    String action, {
    String? truckId,
    double? speedMultiplier,
  }) async {
    try {
      await _client.dio.post<void>(
        '/api/tracking/simulator/control',
        data: {
          'action': action,
          'truckId': ?truckId,
          'speedMultiplier': ?speedMultiplier,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
