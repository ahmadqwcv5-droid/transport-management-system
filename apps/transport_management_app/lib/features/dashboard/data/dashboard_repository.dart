import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/dashboard_models.dart';
import '../domain/active_operation.dart';
import '../../trips/domain/trip_models.dart' as ops;

final class DashboardRepository {
  DashboardRepository(this._client);
  final ApiClient _client;

  Future<Uint8List> authenticatedImage(String url) async {
    try {
      final response = await _client.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<DashboardData> load() async {
    try {
      final response = await _client.dio.get<Json>('/api/dashboard');
      return DashboardData.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ActiveOperationsPage> activeOperations({
    String? search,
    String? clientId,
    String? truckId,
    String? driverId,
    bool attentionOnly = false,
  }) async {
    try {
      final response = await _client.dio.get<Json>(
        '/api/dashboard/active-trips',
        queryParameters: {
          'limit': 100,
          if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
          'clientId': ?clientId,
          'truckId': ?truckId,
          'driverId': ?driverId,
          if (attentionOnly) 'attentionOnly': true,
        },
      );
      return ActiveOperationsPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> simulator(
    String action, {
    String? truckId,
    double? speedMultiplier,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _client.dio.post<void>(
        '/api/tracking/simulator/control',
        data: {
          'action': action,
          'truckId': ?truckId,
          'speedMultiplier': ?speedMultiplier,
          'latitude': ?latitude,
          'longitude': ?longitude,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<FleetTripDetail> tripDetail(String tripId) async {
    try {
      final tripResponse = await _client.dio.get<Json>('/api/trips/$tripId');
      final trip = ops.Trip.fromJson(tripResponse.data!);
      final values = await Future.wait([
        _client.dio.get<Json>('/api/trips/$tripId/route-progress'),
        _client.dio.get<Json>(
          '/api/tracking/trips/$tripId/history',
          queryParameters: {'limit': 500},
        ),
        if (trip.repositioningPlan != null)
          _client.dio.get<Json>('/api/trips/$tripId/repositioning-progress'),
      ]);
      final route = trip.routePlan;
      if (route == null) throw StateError('Trip has no route plan.');
      return FleetTripDetail(
        route: route,
        approachRoute: trip.repositioningPlan?.route,
        progress: ops.RouteProgress.fromJson(values[0].data!),
        approachProgress: trip.repositioningPlan == null
            ? null
            : ops.RouteProgress.fromJson(values[2].data!),
        tripStatus: trip.status,
        trail: (values[1].data!['segments'] as List<dynamic>)
            .cast<Json>()
            .map(TripTrailSegment.fromJson)
            .toList(),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
