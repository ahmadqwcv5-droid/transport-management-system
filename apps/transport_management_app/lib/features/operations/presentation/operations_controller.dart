import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/operations_repository.dart';
import '../domain/operations_data.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>(
  (ref) => OperationsRepository(ref.watch(apiClientProvider)),
);
final operationsControllerProvider =
    AsyncNotifierProvider<OperationsController, OperationsData>(
      OperationsController.new,
    );

class OperationsController extends AsyncNotifier<OperationsData> {
  Timer? _clientSearchDebounce;
  Timer? _truckSearchDebounce;
  String _clientSearch = '';
  String? _clientLifecycle;
  int _clientGeneration = 0;
  String _truckSearch = '';
  String? _truckStatus, _truckType, _truckOperationalState;
  int _truckGeneration = 0;
  OperationsRepository get _repository =>
      ref.read(operationsRepositoryProvider);
  @override
  FutureOr<OperationsData> build() {
    ref.onDispose(() {
      _clientSearchDebounce?.cancel();
      _truckSearchDebounce?.cancel();
    });
    return _repository.load();
  }

  Future<void> reload() async {
    final generation = ++_clientGeneration;
    final truckGeneration = ++_truckGeneration;
    final result = await AsyncValue.guard(() async {
      final loaded = await _repository.load();
      final clients = _clientSearch.isEmpty && _clientLifecycle == null
          ? loaded.clients
          : await _repository.loadClients(
              search: _clientSearch,
              lifecycle: _clientLifecycle,
            );
      final trucks =
          _truckSearch.isEmpty &&
              _truckStatus == null &&
              _truckType == null &&
              _truckOperationalState == null
          ? loaded.trucks
          : await _repository.loadTrucks(
              search: _truckSearch,
              status: _truckStatus,
              type: _truckType,
              operationalState: _truckOperationalState,
            );
      return OperationsData(
        clients: clients,
        trucks: trucks,
        drivers: loaded.drivers,
        trips: loaded.trips,
      );
    });
    if (generation == _clientGeneration &&
        truckGeneration == _truckGeneration) {
      state = result;
    }
  }

  Future<bool> mutate(
    Future<void> Function(OperationsRepository) operation,
  ) async {
    try {
      await operation(_repository);
      await reload();
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  void filterClients(String search, String? lifecycle) {
    _clientSearch = search;
    _clientLifecycle = lifecycle;
    final generation = ++_clientGeneration;
    _clientSearchDebounce?.cancel();
    _clientSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final current = state.value;
      if (current == null) return;
      try {
        final clients = await _repository.loadClients(
          search: search,
          lifecycle: lifecycle,
        );
        if (generation == _clientGeneration) {
          state = AsyncData(
            OperationsData(
              clients: clients,
              trucks: current.trucks,
              drivers: current.drivers,
              trips: current.trips,
            ),
          );
        }
      } catch (_) {
        // Preserve the last visible state; explicit refresh remains available.
      }
    });
  }

  void filterTrucks(
    String search, {
    String? status,
    String? type,
    String? operationalState,
  }) {
    _truckSearch = search;
    _truckStatus = status;
    _truckType = type;
    _truckOperationalState = operationalState;
    final generation = ++_truckGeneration;
    _truckSearchDebounce?.cancel();
    _truckSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final current = state.value;
      if (current == null) return;
      try {
        final trucks = await _repository.loadTrucks(
          search: search,
          status: status,
          type: type,
          operationalState: operationalState,
        );
        if (generation == _truckGeneration) {
          state = AsyncData(
            OperationsData(
              clients: current.clients,
              trucks: trucks,
              drivers: current.drivers,
              trips: current.trips,
            ),
          );
        }
      } catch (_) {
        // Preserve the last visible state; explicit refresh remains available.
      }
    });
  }
}

bool canManageOperations(WidgetRef ref) {
  return ref.watch(operationsCanManageProvider);
}

final operationsCanManageProvider = Provider<bool>((ref) {
  final role = ref.watch(authControllerProvider).value?.user.role;
  return role == 'Owner' || role == 'Operations';
});
