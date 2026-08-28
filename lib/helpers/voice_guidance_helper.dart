import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class VoiceGuidanceHelper {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool isMuted = false;

  /// 🔊 پخش راهنمای صوتی مسیریابی بر اساس مانور، فاصله و زبان فعال
  static Future<void> speakStep(
    String modifier,
    String streetName,
    int distanceMeters,
    String langCode, // fa, ps, en
  ) async {
    if (isMuted) return;

    final lang = langCode.isNotEmpty ? langCode : 'fa';
    final List<String> audioSequence = [];

    // ۱. پخش هشدار فاصله در صورت وجود (مثلاً ۱۰۰ یا ۲۰۰ متر قبل از پیچ)
    if (distanceMeters >= 150 && distanceMeters <= 250) {
      audioSequence.add('in_200m.mp3');
    } else if (distanceMeters >= 70 && distanceMeters <= 120) {
      audioSequence.add('in_100m.mp3');
    }

    // ۲. تعیین فایل صوتی مانور حرکت
    final maneuverFile = _getManeuverAudioFile(modifier);
    if (maneuverFile.isNotEmpty) {
      audioSequence.add(maneuverFile);
    }

    // ۳. پخش متوالی زنجیره راهنما
    for (final fileName in audioSequence) {
      await _playAssetAudio('audio/$lang/$fileName');
    }
  }

  /// نگاشت مانورهای جغرافیایی به فایل‌های صوتی ضبط‌شده
  static String _getManeuverAudioFile(String modifier) {
    switch (modifier.toLowerCase().trim()) {
      case 'right':
      case 'slight right':
      case 'sharp right':
        return 'turn_right.mp3';

      case 'left':
      case 'slight left':
      case 'sharp left':
        return 'turn_left.mp3';

      case 'uturn':
        return 'u_turn.mp3';

      case 'roundabout':
      case 'rotary':
        return 'roundabout.mp3';

      case 'arrived':
      case 'destination':
        return 'arrived.mp3';

      case 'straight':
      default:
        return 'straight.mp3';
    }
  }

  /// اجرای متد پخش صدا از پوشه assets
  static Future<void> _playAssetAudio(String assetPath) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("خطا در پخش فایل صوتی راهنما ($assetPath): $e");
    }
  }

  /// 🛑 قطع تمام صداهای در حال پخش
  static Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint("خطا در توقف پخش صدا: $e");
    }
  }

  /// 🔇/🔊 تغییر وضعیت سکوت
  static void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      stop();
    }
  }
}
