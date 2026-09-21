import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/core/network/api_client.dart';
import 'package:transport_management_app/core/storage/token_store.dart';
import 'package:transport_management_app/features/dashboard/data/dashboard_repository.dart';

void main() {
  test('selected trip requests trip-scoped segmented history', () async {
    final client = ApiClient(TokenStore());
    final adapter = _FixtureAdapter();
    client.dio.httpClientAdapter = adapter;

    final detail = await DashboardRepository(client).tripDetail('trip-1');

    expect(adapter.paths, contains('/api/tracking/trips/trip-1/history'));
    expect(
      adapter.paths.where((path) => path.contains('/tracking/trucks/')),
      isEmpty,
    );
    expect(detail.trail, hasLength(2));
    expect(detail.trail.map((segment) => segment.id), ['run-a', 'run-b']);
    expect(detail.trail[0].points, hasLength(2));
  });
}

final class _FixtureAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final Object body;
    if (options.path.endsWith('/route-progress')) {
      body = {
        'tripId': 'trip-1',
        'truckId': 'truck-1',
        'plannedDistanceMeters': 1000,
        'operationalPhase': 'In transit',
      };
    } else if (options.path.contains('/tracking/trips/')) {
      body = {
        'tripId': 'trip-1',
        'truckId': 'truck-1',
        'pointCount': 3,
        'segments': [
          {
            'id': 'run-a',
            'points': [
              {'latitude': 39.0, 'longitude': 32.0},
              {'latitude': 39.1, 'longitude': 32.1},
            ],
          },
          {
            'id': 'run-b',
            'points': [
              {'latitude': 39.0, 'longitude': 32.0},
            ],
          },
        ],
      };
    } else {
      body = {
        'id': 'trip-1',
        'clientId': 'client-1',
        'truckId': 'truck-1',
        'driverId': 'driver-1',
        'origin': 'A',
        'destination': 'B',
        'cargoDescription': 'Cargo',
        'plannedStartAt': '2026-09-18T00:00:00Z',
        'price': 100,
        'status': 'InTransit',
        'allowedActions': <String>[],
        'stops': <Object>[],
        'requiresLocationSelection': false,
        'routePlan': {
          'geometry': '{"type":"LineString","coordinates":[[32,39],[33,40]]}',
          'coordinates': [
            {'latitude': 39.0, 'longitude': 32.0},
            {'latitude': 40.0, 'longitude': 33.0},
          ],
          'distanceMeters': 1000,
          'estimatedDurationSeconds': 60,
          'providerName': 'Test',
          'routeProfile': 'Driving',
          'calculatedAt': '2026-09-18T00:00:00Z',
          'warnings': <String>[],
        },
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
