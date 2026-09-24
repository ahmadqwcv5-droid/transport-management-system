import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/live_operations_repository.dart';
import '../domain/live_operations_models.dart';

final liveOperationsRepositoryProvider = Provider<LiveOperationsRepository>(
  (ref) => LiveOperationsRepository(ref.watch(apiClientProvider)),
);

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, NotificationPage>(
      NotificationController.new,
    );

class NotificationController extends AsyncNotifier<NotificationPage> {
  Timer? _timer;
  LiveOperationsRepository get _repository =>
      ref.read(liveOperationsRepositoryProvider);

  @override
  Future<NotificationPage> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    return _repository.notifications();
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(await _repository.notifications());
    } on Object {
      // Retain the last good notification projection during polling failures.
    }
  }

  Future<void> markRead(String id) async {
    await _repository.markRead(id);
    await refresh();
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    await refresh();
  }
}

final driverTripControllerProvider =
    AsyncNotifierProvider<DriverTripController, DriverMyTrip>(
      DriverTripController.new,
    );

class DriverTripController extends AsyncNotifier<DriverMyTrip> {
  Timer? _timer;
  LiveOperationsRepository get _repository =>
      ref.read(liveOperationsRepositoryProvider);

  @override
  Future<DriverMyTrip> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    return _repository.myTrip();
  }

  Future<void> refresh() async {
    try {
      state = AsyncData(await _repository.myTrip());
    } on Object {
      // Keep the current operational card when a poll fails.
    }
  }

  Future<bool> confirm({required bool delivery}) async {
    try {
      if (delivery) {
        await _repository.confirmDelivery();
      } else {
        await _repository.confirmLoaded();
      }
      await refresh();
      ref.read(notificationControllerProvider.notifier).refresh();
      return true;
    } on Object {
      return false;
    }
  }
}
