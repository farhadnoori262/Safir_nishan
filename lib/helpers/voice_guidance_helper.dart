import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceGuidanceHelper {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool isMuted = false;

  /// 🔊 پخش فایل صوتی ضبط‌شده بر اساس مانور
  static Future<void> speakStep(
    String modifier,
    String streetName,
    int distanceMeters,
    String langCode, // fa, ps, en
  ) async {
    if (isMuted) return;

    String fileName = '';

    switch (modifier.toLowerCase()) {
      case 'right':
      case 'slight right':
      case 'sharp right':
        fileName = 'turn_right.mp3';
        break;

      case 'left':
      case 'slight left':
      case 'sharp left':
        fileName = 'turn_left.mp3';
        break;

      case 'arrived':
        fileName = 'arrived.mp3';
        break;

      case 'straight':
      default:
        fileName = 'straight.mp3';
        break;
    }

    if (fileName.isNotEmpty) {
      try {
        await _audioPlayer.stop(); // قطع صدای قبلی برای پخش صدای جدید
        // پخش فایل از مسیر assets/audio/fa/filename.mp3
        await _audioPlayer.play(AssetSource('audio/$langCode/$fileName'));
      } catch (e) {
        debugPrint("خطا در پخش فایل صوتی: $e");
      }
    }
  }

  /// 🛑 قطع صدا
  static Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// 🔇/🔊 تغییر وضعیت بی‌صدا
  static void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      stop();
    }
  }
}
