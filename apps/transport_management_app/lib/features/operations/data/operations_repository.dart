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
      queryTrips(pageSize: 20),
    ]);
    return OperationsData(
      clients: values[0] as List<Client>,
      trucks: values[1] as List<Truck>,
      drivers: values[2] as List<Driver>,
      trips: (values[3] as TripPage).items,
    );
  }

  Future<TripPage> queryTrips({int page = 1, int pageSize = 20,
    String? search, String? operationalGroup, String? status,
    String? clientId, String? truckId, String? driverId,
    String? plannedFrom, String? plannedTo}) async {
    try {
      final response = await _client.dio.get<Json>('/api/trips', queryParameters: {
        'page': page, 'pageSize': pageSize,
        'search': search?.trim().isEmpty == true ? null : search?.trim(),
        'operationalGroup': operationalGroup,
        'status': status,
        'clientId': clientId,
        'truckId': truckId,
        'driverId': driverId,
        'plannedFrom': plannedFrom,
        'plannedTo': plannedTo,
      });
      return TripPage.fromJson(response.data!);
    } on DioException catch (error) { throw ApiException.fromDio(error); }
  }

  Future<Trip> getTrip(String id) async {
    try {
      final response = await _client.dio.get<Json>('/api/trips/$id');
      return Trip.fromJson(response.data!);
    } on DioException catch (error) { throw ApiException.fromDio(error); }
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
  Future<Trip> saveTrip(Json data, [String? id]) async {
    try {
      final response = await _client.dio.request<Json>(
        id == null ? '/api/trips' : '/api/trips/$id',
        data: data,
        options: Options(method: id == null ? 'POST' : 'PUT'),
      );
      return Trip.fromJson(response.data!);
    } on DioException catch (error) { throw ApiException.fromDio(error); }
  }
  Future<void> deactivate(String kind, String id) =>
      _send('POST', '/api/$kind/$id/deactivate');
  Future<void> setFleetStatus(String kind, String id, String status) =>
      _send('PUT', '/api/$kind/$id/status', {'status': status});
  Future<void> assignTrip(String id, String truckId, String driverId) => _send(
    'POST',
    '/api/trips/$id/assign',
    {'truckId': truckId, 'driverId': driverId},
  );
  Future<void> reassignTrip(String id, String truckId, String driverId) =>
      _send('POST', '/api/trips/$id/reassign', {'truckId': truckId, 'driverId': driverId});
  Future<void> unassignTrip(String id) => _send('POST', '/api/trips/$id/unassign');
  Future<void> deleteDraft(String id) => _send('DELETE', '/api/trips/$id/draft');
  Future<void> duplicateTrip(String id) => _send('POST', '/api/trips/$id/duplicate');
  Future<void> cancelTrip(String id, String reason) =>
      _send('POST', '/api/trips/$id/cancel', {'reason': reason});
  Future<void> archiveTrip(String id, {required bool archive}) =>
      _send('POST', '/api/trips/$id/${archive ? 'archive' : 'unarchive'}');
  Future<void> saveTripStops(String id, List<TripStop> stops, int version) =>
      _send('PUT', '/api/trips/$id/stops', {
        'stops': stops.map((item) => item.toJson()).toList(), 'expectedVersion': version,
      });
  Future<Trip> calculateTripRoute(String id) async {
    try {
      final response = await _client.dio.post<Json>('/api/trips/$id/calculate-route',
        data: {'routeProfile': 'Driving'});
      return Trip.fromJson(response.data!);
    } on DioException catch (error) { throw ApiException.fromDio(error); }
  }
  Future<List<TripEvent>> timeline(String id) async {
    try {
      final response = await _client.dio.get<Json>('/api/trips/$id/timeline');
      return (response.data!['items'] as List<dynamic>).cast<Json>()
          .map(TripEvent.fromJson).toList();
    } on DioException catch (error) { throw ApiException.fromDio(error); }
  }
  Future<void> tripAction(String id, String action) => _send(
    'POST',
    '/api/trips/$id/${action == 'MarkInTransit' ? 'mark-in-transit' : action.toLowerCase()}',
  );

  Future<RepositioningPreview> previewRepositioning(String tripId) async {
    try {
      final response = await _client.dio.post<Json>(
        '/api/trips/$tripId/repositioning/preview',
      );
      return RepositioningPreview.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> dispatchToPickup(String tripId, String? planId) => _send(
    'POST',
    '/api/trips/$tripId/dispatch-to-pickup',
    {'repositioningPlanId': planId},
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
