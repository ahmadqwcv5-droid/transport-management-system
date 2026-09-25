import 'package:flutter/services.dart';

import 'notification_audio_contract.dart';

NotificationAudioPlayer createNotificationAudioPlayer() =>
    _SystemNotificationAudioPlayer();

final class _SystemNotificationAudioPlayer implements NotificationAudioPlayer {
  bool _unlocked = false;
  @override
  bool get isUnlocked => _unlocked;
  @override
  Future<NotificationSoundResult> unlock() async {
    _unlocked = true;
    return NotificationSoundResult.played;
  }

  @override
  Future<NotificationSoundResult> play() async {
    if (!_unlocked) return NotificationSoundResult.blocked;
    try {
      await SystemSound.play(SystemSoundType.alert);
      return NotificationSoundResult.played;
    } on Object {
      return NotificationSoundResult.failed;
    }
  }

  @override
  void dispose() {}
}
