import 'notification_audio_contract.dart';
import 'notification_audio_stub.dart'
    if (dart.library.html) 'notification_audio_web.dart'
    as platform;

NotificationAudioPlayer createNotificationAudioPlayer() =>
    platform.createNotificationAudioPlayer();
