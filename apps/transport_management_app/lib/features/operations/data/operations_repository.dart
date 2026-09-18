import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/operations_models.dart';

final class OperationsRepository {
  OperationsRepository(this._client);
  final ApiClient _client;

  Future<List<T>> _list<T>(String path, T Function(Json) decode) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(path);
      return response.data!.cast<Json>().map(decode).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<OperationsData> load() async {
    final values = await Future.wait<Object>([
      _list('/api/clients', Client.fromJson),
      _list('/api/trucks', Truck.fromJson),
      _list('/api/drivers', Driver.fromJson),
      _list('/api/trips', Trip.fromJson),
    ]);
    return OperationsData(
      clients: values[0] as List<Client>,
      trucks: values[1] as List<Truck>,
      drivers: values[2] as List<Driver>,
      trips: values[3] as List<Trip>,
    );
  }

  Future<void> _send(String method, String path, [Json? data]) async {
    try {
      await _client.dio.request<void>(
        path,
        data: data,
        options: Options(method: method),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> saveClient(Json data, [String? id]) => _send(
    id == null ? 'POST' : 'PUT',
    id == null ? '/api/clients' : '/api/clients/$id',
    data,
  );
  Future<void> saveTruck(Json data, [String? id]) => _send(
    id == null ? 'POST' : 'PUT',
    id == null ? '/api/trucks' : '/api/trucks/$id',
    data,
  );
  Future<void> saveDriver(Json data, [String? id]) => _send(
    id == null ? 'POST' : 'PUT',
    id == null ? '/api/drivers' : '/api/drivers/$id',
    data,
  );
  Future<void> saveTrip(Json data, [String? id]) => _send(
    id == null ? 'POST' : 'PUT',
    id == null ? '/api/trips' : '/api/trips/$id',
    data,
  );
  Future<void> deactivate(String kind, String id) =>
      _send('POST', '/api/$kind/$id/deactivate');
  Future<void> setFleetStatus(String kind, String id, String status) =>
      _send('PUT', '/api/$kind/$id/status', {'status': status});
  Future<void> assignTrip(String id, String truckId, String driverId) => _send(
    'POST',
    '/api/trips/$id/assign',
    {'truckId': truckId, 'driverId': driverId},
  );
  Future<void> tripAction(String id, String action) => _send(
    'POST',
    '/api/trips/$id/${action == 'MarkInTransit' ? 'mark-in-transit' : action.toLowerCase()}',
  );

  Future<List<LocationResult>> searchLocations(String query) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/api/locations/search',
        queryParameters: {'query': query},
      );
      return response.data!.cast<Json>().map(LocationResult.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TripRoutePlan> previewRoute(List<TripStop> stops) async {
    try {
      final response = await _client.dio.post<Json>(
        '/api/routes/preview',
        data: {
          'routeProfile': 'Driving',
          'stops': stops.map((item) => item.toJson()).toList(),
        },
      );
      return TripRoutePlan.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<RouteProgress> routeProgress(String tripId) async {
    try {
      final response = await _client.dio.get<Json>(
        '/api/trips/$tripId/route-progress',
      );
      return RouteProgress.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
