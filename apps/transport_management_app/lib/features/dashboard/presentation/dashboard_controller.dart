import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);
final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
      DashboardController.new,
    );

class DashboardController extends AsyncNotifier<DashboardData> {
  static const _pollingIntervalSeconds = int.fromEnvironment(
    'TRACKING_POLLING_INTERVAL_SECONDS',
    defaultValue: 2,
  );
  static const _safePollingIntervalSeconds = _pollingIntervalSeconds > 0
      ? _pollingIntervalSeconds
      : 2;
  Timer? _timer;
  bool _refreshing = false;
  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);
  @override
  FutureOr<DashboardData> build() {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(
      const Duration(seconds: _safePollingIntervalSeconds),
      (_) => refresh(silent: true),
    );
    return _repository.load();
  }

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent) state = const AsyncLoading();
    try {
      final result = await AsyncValue.guard(_repository.load);
      if (ref.mounted) state = result;
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> control(
    String action, {
    String? truckId,
    double? speedMultiplier,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _repository.simulator(
        action,
        truckId: truckId,
        speedMultiplier: speedMultiplier,
        latitude: latitude,
        longitude: longitude,
      );
      await refresh(silent: true);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}
