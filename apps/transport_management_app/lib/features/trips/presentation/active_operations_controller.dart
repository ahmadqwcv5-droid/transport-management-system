import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/domain/active_operation.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

final activeOperationsControllerProvider =
    AsyncNotifierProvider<ActiveOperationsController, ActiveOperationsPage>(
      ActiveOperationsController.new,
    );

class ActiveOperationsController extends AsyncNotifier<ActiveOperationsPage> {
  static const _configuredSeconds = int.fromEnvironment(
    'ACTIVE_OPERATIONS_POLLING_INTERVAL_SECONDS',
    defaultValue: 3,
  );
  static final _interval = Duration(seconds: _configuredSeconds.clamp(2, 10));

  Timer? _timer;
  bool _refreshing = false;
  int _generation = 0;
  int _failures = 0;
  String? search, clientId, truckId, driverId;
  bool attentionOnly = false;

  bool get isStale => _failures >= 2;

  @override
  FutureOr<ActiveOperationsPage> build() {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(_interval, (_) => refresh(silent: true));
    return _load();
  }

  Future<ActiveOperationsPage> _load() => ref
      .read(dashboardRepositoryProvider)
      .activeOperations(
        search: search,
        clientId: clientId,
        truckId: truckId,
        driverId: driverId,
        attentionOnly: attentionOnly,
      );

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    final generation = ++_generation;
    if (!silent && !state.hasValue) state = const AsyncLoading();
    try {
      final result = await _load();
      if (!ref.mounted || generation != _generation) return;
      _failures = 0;
      state = AsyncData(result);
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      _failures++;
      // Silent polling deliberately preserves the last usable projection.
      if (!silent || !state.hasValue) state = AsyncError(error, stack);
    } finally {
      _refreshing = false;
    }
  }

  void setSearch(String value) {
    search = value;
    refresh(silent: state.hasValue);
  }

  void setFilters({String? client, String? truck, String? driver}) {
    clientId = client ?? clientId;
    truckId = truck ?? truckId;
    driverId = driver ?? driverId;
    refresh(silent: state.hasValue);
  }

  void clearFilters() {
    clientId = null;
    truckId = null;
    driverId = null;
    attentionOnly = false;
    refresh(silent: state.hasValue);
  }
}
