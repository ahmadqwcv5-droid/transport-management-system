// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/services.dart';

import 'notification_audio_contract.dart';

NotificationAudioPlayer createNotificationAudioPlayer() =>
    _WebNotificationAudioPlayer();

final class _WebNotificationAudioPlayer implements NotificationAudioPlayer {
  html.AudioElement? _audio;
  bool _unlocked = false;
  Future<html.AudioElement> _load() async {
    final existing = _audio;
    if (existing != null) return existing;
    final encoded = (await rootBundle.loadString(
      'assets/audio/notification_tone.wav.b64',
    )).trim();
    final audio = html.AudioElement('data:audio/wav;base64,$encoded')
      ..preload = 'auto';
    _audio = audio;
    return audio;
  }

  @override
  bool get isUnlocked => _unlocked;

  @override
  Future<NotificationSoundResult> unlock() async {
    try {
      final audio = await _load();
      audio.volume = 0;
      await audio.play();
      audio.pause();
      audio.currentTime = 0;
      audio.volume = 1;
      _unlocked = true;
      return NotificationSoundResult.played;
    } on Object {
      return NotificationSoundResult.blocked;
    }
  }

  @override
  Future<NotificationSoundResult> play() async {
    if (!_unlocked) return NotificationSoundResult.blocked;
    try {
      final audio = await _load();
      audio.currentTime = 0;
      await audio.play();
      return NotificationSoundResult.played;
    } on Object {
      _unlocked = false;
      return NotificationSoundResult.blocked;
    }
  }

  @override
  void dispose() {
    _audio?.pause();
    _audio = null;
    _unlocked = false;
  }
}
