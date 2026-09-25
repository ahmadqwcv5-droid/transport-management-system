import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/features/live_operations/audio/notification_audio_contract.dart';
import 'package:transport_management_app/features/live_operations/domain/live_operations_models.dart';
import 'package:transport_management_app/features/live_operations/presentation/live_operations_controller.dart';

void main() {
  test('initial hydration is silent and repeated polls stay deduplicated', () {
    final tracker = NotificationDeliveryTracker();
    tracker.hydrate([notification('historical')]);

    expect(tracker.takeUnseen([notification('historical')]), isEmpty);
    expect(
      tracker
          .takeUnseen([
            notification('new', at: '2026-09-25T00:01:00Z'),
            notification('historical'),
          ])
          .map((item) => item.id),
      ['new'],
    );
    expect(tracker.takeUnseen([notification('new')]), isEmpty);
  });

  test('one new alert queues once and requests at most one sound', () async {
    final audio = FakeNotificationAudioPlayer();
    final container = ProviderContainer(
      overrides: [notificationAudioPlayerProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      operationalAlertControllerProvider.notifier,
    );

    await controller.enqueue(notification('one'), soundEnabled: true);
    await controller.enqueue(notification('one'), soundEnabled: true);

    final state = container.read(operationalAlertControllerProvider);
    expect(state.queue.map((item) => item.id), ['one']);
    expect(state.soundPlayRequests, 1);
    expect(audio.playCalls, 1);
  });

  test(
    'burst rate limit and disabled preference prevent extra playback',
    () async {
      final audio = FakeNotificationAudioPlayer();
      final container = ProviderContainer(
        overrides: [notificationAudioPlayerProvider.overrideWithValue(audio)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        operationalAlertControllerProvider.notifier,
      );

      await controller.enqueue(notification('one'), soundEnabled: true);
      await controller.enqueue(notification('two'), soundEnabled: true);
      await controller.enqueue(notification('three'), soundEnabled: false);

      expect(
        container
            .read(operationalAlertControllerProvider)
            .queue
            .map((item) => item.id),
        ['one', 'two', 'three'],
      );
      expect(audio.playCalls, 1);
    },
  );

  test('blocked audio is reflected honestly and can be unlocked', () async {
    final audio = FakeNotificationAudioPlayer(
      playResult: NotificationSoundResult.blocked,
    );
    final container = ProviderContainer(
      overrides: [notificationAudioPlayerProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      operationalAlertControllerProvider.notifier,
    );

    await controller.enqueue(notification('one'), soundEnabled: true);
    expect(
      container.read(operationalAlertControllerProvider).soundBlocked,
      isTrue,
    );
    await controller.unlockSound();
    expect(audio.unlockCalls, 1);
  });
}

OperationNotification notification(
  String id, {
  String at = '2026-09-25T00:00:00Z',
}) => OperationNotification(
  id: id,
  type: 'TripAssignedToDriver',
  severity: 'Information',
  createdAt: at,
);

final class FakeNotificationAudioPlayer implements NotificationAudioPlayer {
  FakeNotificationAudioPlayer({
    this.playResult = NotificationSoundResult.played,
  });

  final NotificationSoundResult playResult;
  int playCalls = 0;
  int unlockCalls = 0;
  bool _unlocked = false;

  @override
  bool get isUnlocked => _unlocked;

  @override
  Future<NotificationSoundResult> play() async {
    playCalls++;
    return playResult;
  }

  @override
  Future<NotificationSoundResult> unlock() async {
    unlockCalls++;
    _unlocked = true;
    return NotificationSoundResult.played;
  }

  @override
  void dispose() {}
}
