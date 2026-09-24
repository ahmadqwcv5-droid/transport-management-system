import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../clients/domain/client_models.dart' hide Json;
import '../../fleet/domain/fleet_models.dart' hide Json;
import '../domain/operations_data.dart';
import '../../trips/domain/trip_models.dart';

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

  Future<List<Client>> loadClients({String? search, String? lifecycle}) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/api/clients',
        queryParameters: {
          'search': search?.trim().isEmpty == true ? null : search?.trim(),
          'lifecycle': lifecycle,
        },
      );
      return response.data!.cast<Json>().map(Client.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<Truck>> loadTrucks({
    String? search,
    String? status,
    String? type,
    String? operationalState,
  }) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/api/trucks',
        queryParameters: {
          'search': search?.trim().isEmpty == true ? null : search?.trim(),
          'status': status,
          'type': type,
          'operationalState': operationalState,
        },
      );
      return response.data!.cast<Json>().map(Truck.fromJson).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TripPage> queryTrips({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? operationalGroup,
    String? status,
    String? clientId,
    String? truckId,
    String? driverId,
    String? plannedFrom,
    String? plannedTo,
  }) async {
    try {
      final response = await _client.dio.get<Json>(
        '/api/trips',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'search': search?.trim().isEmpty == true ? null : search?.trim(),
          'operationalGroup': operationalGroup,
          'status': status,
          'clientId': clientId,
          'truckId': truckId,
          'driverId': driverId,
          'plannedFrom': plannedFrom,
          'plannedTo': plannedTo,
        },
      );
      return TripPage.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Trip> getTrip(String id) async {
    try {
      final response = await _client.dio.get<Json>('/api/trips/$id');
      return Trip.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
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
  Future<ClientDetails> clientDetails(String id) async {
    try {
      final response = await _client.dio.get<Json>('/api/clients/$id/details');
      return ClientDetails.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TruckDetails> truckDetails(String id) async {
    try {
      final response = await _client.dio.get<Json>('/api/trucks/$id/details');
      return TruckDetails.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> setClientLifecycle(String id, String status) =>
      _send('PUT', '/api/clients/$id/lifecycle', {'status': status});
  Future<void> deleteResource(String kind, String id) =>
      _send('DELETE', '/api/$kind/$id');
  Future<void> saveClientContact(String clientId, Json data, [String? id]) =>
      _send(
        id == null ? 'POST' : 'PUT',
        '/api/clients/$clientId/contacts${id == null ? '' : '/$id'}',
        data,
      );
  Future<void> deleteClientContact(String clientId, String id) =>
      _send('DELETE', '/api/clients/$clientId/contacts/$id');
  Future<void> saveClientSite(String clientId, Json data, [String? id]) =>
      _send(
        id == null ? 'POST' : 'PUT',
        '/api/clients/$clientId/sites${id == null ? '' : '/$id'}',
        data,
      );
  Future<void> setClientSiteActive(String clientId, String id, bool active) =>
      _send(
        'POST',
        '/api/clients/$clientId/sites/$id/${active ? 'restore' : 'archive'}',
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
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deactivate(String kind, String id) =>
      _send('POST', '/api/$kind/$id/deactivate');
  Future<void> setFleetStatus(String kind, String id, String status) =>
      _send('PUT', '/api/$kind/$id/status', {'status': status});
  Future<void> correctTruckOdometer(String id, num kilometers, String reason) =>
      _send('PUT', '/api/trucks/$id/odometer-correction', {
        'kilometers': kilometers,
        'reason': reason,
      });
  Future<void> assignTrip(String id, String truckId, String driverId) => _send(
    'POST',
    '/api/trips/$id/assign',
    {'truckId': truckId, 'driverId': driverId},
  );
  Future<Trip> assignTripAndGet(
    String id,
    String truckId,
    String driverId,
  ) async {
    try {
      final response = await _client.dio.post<Json>(
        '/api/trips/$id/assign',
        data: {'truckId': truckId, 'driverId': driverId},
      );
      return Trip.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> reassignTrip(String id, String truckId, String driverId) =>
      _send('POST', '/api/trips/$id/reassign', {
        'truckId': truckId,
        'driverId': driverId,
      });
  Future<void> unassignTrip(String id) =>
      _send('POST', '/api/trips/$id/unassign');
  Future<void> deleteDraft(String id) =>
      _send('DELETE', '/api/trips/$id/draft');
  Future<void> duplicateTrip(String id) =>
      _send('POST', '/api/trips/$id/duplicate');
  Future<void> cancelTrip(String id, String reason) =>
      _send('POST', '/api/trips/$id/cancel', {'reason': reason});
  Future<void> archiveTrip(String id, {required bool archive}) =>
      _send('POST', '/api/trips/$id/${archive ? 'archive' : 'unarchive'}');
  Future<Trip> saveTripStops(
    String id,
    List<TripStop> stops,
    int version,
  ) async {
    try {
      final response = await _client.dio.put<Json>(
        '/api/trips/$id/stops',
        data: {
          'stops': stops.map((item) => item.toJson()).toList(),
          'expectedVersion': version,
        },
      );
      return Trip.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AssignmentOptions> assignmentOptions(String id) async {
    try {
      final response = await _client.dio.get<Json>(
        '/api/trips/$id/assignment-options',
      );
      return AssignmentOptions.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Trip> calculateTripRoute(String id) async {
    try {
      final response = await _client.dio.post<Json>(
        '/api/trips/$id/calculate-route',
        data: {'routeProfile': 'Driving'},
      );
      return Trip.fromJson(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<TripEvent>> timeline(String id) async {
    try {
      final response = await _client.dio.get<Json>('/api/trips/$id/timeline');
      return (response.data!['items'] as List<dynamic>)
          .cast<Json>()
          .map(TripEvent.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> tripAction(String id, String action) => _send(
    'POST',
    '/api/trips/$id/${action == 'MarkInTransit' ? 'mark-in-transit' : action.toLowerCase()}',
  );

  Future<void> managerOverride(String id, String action, String reason) =>
      _send('POST', '/api/trips/$id/override/$action', {'reason': reason});

  Future<void> uploadTruckPhoto(
    String id,
    List<int> bytes,
    String filename,
  ) async {
    try {
      await _client.dio.post<void>(
        '/api/trucks/$id/photo',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        }),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> removeTruckPhoto(String id) =>
      _send('DELETE', '/api/trucks/$id/photo');

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
