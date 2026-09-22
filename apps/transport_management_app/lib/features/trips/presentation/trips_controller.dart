import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../operations/domain/operations_models.dart';
import '../../operations/presentation/operations_controller.dart';

final tripsControllerProvider =
    AsyncNotifierProvider<TripsController, TripPage>(TripsController.new);

class TripsController extends AsyncNotifier<TripPage> {
  String group = 'active';
  String search = '';
  String? clientId, truckId, driverId;
  int page = 1;
  int _generation = 0;
  Timer? _debounce;

  @override
  FutureOr<TripPage> build() {
    ref.onDispose(() => _debounce?.cancel());
    return _load();
  }

  Future<TripPage> _load() => ref.read(operationsRepositoryProvider).queryTrips(
    page: page,
    search: search,
    operationalGroup: group,
    clientId: clientId,
    truckId: truckId,
    driverId: driverId,
  );

  Future<void> refresh() async {
    final generation = ++_generation;
    final result = await AsyncValue.guard(_load);
    if (generation == _generation) state = result;
  }

  void setGroup(String value) {
    group = value;
    page = 1;
    refresh();
  }

  void setSearch(String value) {
    search = value;
    page = 1;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  void setFilters({String? client, String? truck, String? driver}) {
    clientId = client;
    truckId = truck;
    driverId = driver;
    page = 1;
    refresh();
  }

  void clearFilters() => setFilters();

  void goToPage(int value) {
    page = value;
    refresh();
  }
}
