import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../data/live_operations_repository.dart';
import '../domain/live_operations_models.dart';
import '../audio/notification_audio.dart';
import '../audio/notification_audio_contract.dart';

final liveOperationsRepositoryProvider = Provider<LiveOperationsRepository>(
  (ref) => LiveOperationsRepository(ref.watch(apiClientProvider)),
);

final notificationAudioPlayerProvider = Provider<NotificationAudioPlayer>((
  ref,
) {
  final player = createNotificationAudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

final operationalAlertControllerProvider =
    NotifierProvider<OperationalAlertController, OperationalAlertState>(
      OperationalAlertController.new,
    );

final class OperationalAlertState {
  const OperationalAlertState({
    this.queue = const [],
    this.soundBlocked = false,
    this.soundPlayRequests = 0,
  });
  final List<OperationNotification> queue;
  final bool soundBlocked;
  final int soundPlayRequests;
  OperationNotification? get current => queue.firstOrNull;
}

class OperationalAlertController extends Notifier<OperationalAlertState> {
  DateTime? _lastSoundAt;
  @override
  OperationalAlertState build() => const OperationalAlertState();

  Future<void> enqueue(
    OperationNotification notification, {
    required bool soundEnabled,
  }) async {
    if (state.queue.any((item) => item.id == notification.id)) return;
    final queue = [...state.queue, notification];
    state = OperationalAlertState(
      queue: queue.length > 10 ? queue.sublist(queue.length - 10) : queue,
      soundBlocked: state.soundBlocked,
      soundPlayRequests: state.soundPlayRequests,
    );
    if (!soundEnabled) return;
    final now = DateTime.now();
    if (_lastSoundAt != null &&
        now.difference(_lastSoundAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastSoundAt = now;
    final result = await ref.read(notificationAudioPlayerProvider).play();
    state = OperationalAlertState(
      queue: state.queue,
      soundBlocked: result == NotificationSoundResult.blocked,
      soundPlayRequests: state.soundPlayRequests + 1,
    );
  }

  Future<void> unlockSound() async {
    final result = await ref.read(notificationAudioPlayerProvider).unlock();
    state = OperationalAlertState(
      queue: state.queue,
      soundBlocked: result == NotificationSoundResult.blocked,
      soundPlayRequests: state.soundPlayRequests,
    );
  }

  Future<NotificationSoundResult> testSound() async {
    final player = ref.read(notificationAudioPlayerProvider);
    if (!player.isUnlocked) await unlockSound();
    final result = await player.play();
    state = OperationalAlertState(
      queue: state.queue,
      soundBlocked: result == NotificationSoundResult.blocked,
      soundPlayRequests: state.soundPlayRequests + 1,
    );
    return result;
  }

  void dismiss() {
    if (state.queue.isEmpty) return;
    state = OperationalAlertState(
      queue: state.queue.sublist(1),
      soundBlocked: state.soundBlocked,
      soundPlayRequests: state.soundPlayRequests,
    );
  }

  void clear() {
    _lastSoundAt = null;
    state = const OperationalAlertState();
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, NotificationPage>(
      NotificationController.new,
    );

/// Tracks persisted notification IDs across polling cycles. Hydration only
/// establishes the baseline; it never treats historical items as live alerts.
final class NotificationDeliveryTracker {
  final Set<String> _seenIds = {};

  void hydrate(Iterable<OperationNotification> notifications) {
    _seenIds
      ..clear()
      ..addAll(notifications.map((item) => item.id));
  }

  List<OperationNotification> takeUnseen(
    Iterable<OperationNotification> notifications,
  ) {
    final unseen = notifications
        .where((item) => _seenIds.add(item.id))
        .toList();
    unseen.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return unseen;
  }

  void clear() => _seenIds.clear();
}

class NotificationController extends AsyncNotifier<NotificationPage> {
  Timer? _timer;
  bool _refreshing = false;
  final NotificationDeliveryTracker _delivery = NotificationDeliveryTracker();
  LiveOperationsRepository get _repository =>
      ref.read(liveOperationsRepositoryProvider);

  @override
  Future<NotificationPage> build() async {
    final user = ref.watch(authControllerProvider).value?.user;
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (user == null) {
      _delivery.clear();
      ref.read(operationalAlertControllerProvider.notifier).clear();
      return const NotificationPage(items: [], totalCount: 0);
    }
    final initial = await _repository.notifications();
    _delivery.hydrate(initial.items);
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    return initial;
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final page = await _repository.notifications();
      final unseen = _delivery.takeUnseen(page.items);
      state = AsyncData(page);
      final enabled =
          ref
              .read(authControllerProvider)
              .value
              ?.user
              .notificationSoundsEnabled ??
          false;
      for (final notification in unseen) {
        await ref
            .read(operationalAlertControllerProvider.notifier)
            .enqueue(notification, soundEnabled: enabled);
      }
    } on Object {
      // Retain the last good notification projection during polling failures.
    } finally {
      _refreshing = false;
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
    AsyncNotifierProvider<DriverTripController, DriverWorkspace>(
      DriverTripController.new,
    );

class DriverTripController extends AsyncNotifier<DriverWorkspace> {
  Timer? _timer;
  bool _refreshing = false;
  bool _acting = false;
  int _consecutiveFailures = 0;
  LiveOperationsRepository get _repository =>
      ref.read(liveOperationsRepositoryProvider);

  @override
  Future<DriverWorkspace> build() async {
    ref.watch(authControllerProvider);
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    return _repository.workspace();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final workspace = await _repository.workspace();
      _consecutiveFailures = 0;
      state = AsyncData(workspace);
    } on Object {
      _consecutiveFailures++;
      final current = state.value;
      if (current != null && _consecutiveFailures >= 2) {
        state = AsyncData(current.copyWithUiState(connectionWarning: true));
      }
    } finally {
      _refreshing = false;
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

  Future<DriverActionResult> depart() async {
    if (_acting) {
      return const DriverActionResult.failure('DEPARTURE_ALREADY_IN_PROGRESS');
    }
    _acting = true;
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWithUiState(actionInProgress: true));
    }
    try {
      await _repository.departToPickup();
      final workspace = await _repository.workspace();
      _consecutiveFailures = 0;
      state = AsyncData(workspace);
      ref.read(notificationControllerProvider.notifier).refresh();
      return const DriverActionResult.success();
    } on ApiException catch (error) {
      if (current != null) {
        state = AsyncData(current.copyWithUiState(actionInProgress: false));
      }
      return DriverActionResult.failure(error.code);
    } on Object {
      if (current != null) {
        state = AsyncData(current.copyWithUiState(actionInProgress: false));
      }
      return const DriverActionResult.failure(null);
    } finally {
      _acting = false;
    }
  }

  Future<bool> endVehicleSession() => _action(_repository.endVehicleSession);

  Future<bool> _action(Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      ref.read(notificationControllerProvider.notifier).refresh();
      return true;
    } on Object {
      return false;
    }
  }
}

final class DriverActionResult {
  const DriverActionResult.success() : succeeded = true, errorCode = null;
  const DriverActionResult.failure(this.errorCode) : succeeded = false;
  final bool succeeded;
  final String? errorCode;
}
