enum NotificationSoundResult { played, blocked, failed }

abstract interface class NotificationAudioPlayer {
  bool get isUnlocked;
  Future<NotificationSoundResult> unlock();
  Future<NotificationSoundResult> play();
  void dispose();
}
