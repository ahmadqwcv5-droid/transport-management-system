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
    defaultValue: 5,
  );
  static const _safePollingIntervalSeconds = _pollingIntervalSeconds > 0
      ? _pollingIntervalSeconds
      : 5;
  Timer? _timer;
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
    if (!silent) state = const AsyncLoading();
    final result = await AsyncValue.guard(_repository.load);
    if (ref.mounted) state = result;
  }

  Future<bool> control(String action, {String? truckId}) async {
    try {
      await _repository.simulator(action, truckId: truckId);
      await refresh(silent: true);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}
