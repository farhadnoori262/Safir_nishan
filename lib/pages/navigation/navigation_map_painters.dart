import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../utils/app_colors.dart';

enum TurnDirection {
  left,
  right,
  straight,
  uTurn,
}

class NavigationMapPainters {
  static ui.Image? _cachedDriverImage;
  static bool _isLoadingImage = false;

  static Future<void> addCanvasImage(
    MapLibreMapController controller,
    String name,
    void Function(Canvas canvas, Size size) painter, {
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    painter(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    if (bytes == null) return;
    await controller.addImage(name, bytes.buffer.asUint8List());
  }

  static void drawCurrentLocationPulse(
    Canvas canvas,
    Size size,
    double pulseValue,
    double currentAccuracy,
  ) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseAccuracyRadius = currentAccuracy.clamp(15.0, 60.0);
    final animatedRadius = baseAccuracyRadius * (1.0 - pulseValue);
    final outerOpacity = (0.35 * (1.0 - pulseValue)).clamp(0.0, 0.35);

    if (animatedRadius > 5) {
      canvas.drawCircle(
        center,
        animatedRadius,
        Paint()
          ..color = SafirColors.primary.withOpacity(outerOpacity)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawCircle(
      center,
      18,
      Paint()..color = SafirColors.primary.withOpacity(0.20),
    );
    canvas.drawCircle(center, 12, Paint()..color = Colors.white);
    canvas.drawCircle(center, 8, Paint()..color = SafirColors.primary);
  }

  static void drawDriverArrow(Canvas canvas, Size size) {
    // اگر تصویر بارگیری شده باشد، آن را قرار می‌دهد
    if (_cachedDriverImage != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        _cachedDriverImage!.width.toDouble(),
        _cachedDriverImage!.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(_cachedDriverImage!, srcRect, dstRect, Paint());
      return;
    }

    // لود خودکار تصویر در پس‌زمینه
    if (!_isLoadingImage) {
      _isLoadingImage = true;
      rootBundle.load('assets/images/driver_arrow.png').then((data) {
        ui.instantiateImageCodec(data.buffer.asUint8List()).then((codec) {
          codec.getNextFrame().then((frameInfo) {
            _cachedDriverImage = frameInfo.image;
          });
        });
      }).catchError((_) {
        _isLoadingImage = false;
      });
    }

    // تا زمان لود شدن تصویر جدید، از فلش قبلی استفاده می‌کند
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, 8)
      ..lineTo(size.width - 18, size.height - 19)
      ..quadraticBezierTo(size.width - 16, size.height - 10, size.width - 27, size.height - 15)
      ..lineTo(center.dx, size.height - 35)
      ..lineTo(27, size.height - 15)
      ..quadraticBezierTo(16, size.height - 10, 18, size.height - 19)
      ..close();

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(path.shift(const Offset(0, 5)), shadowPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, Paint()..color = SafirColors.primary);
  }

  static void drawDestinationPin(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final pinBottom = size.height - 7.0;

    final path = Path()
      ..moveTo(centerX, pinBottom)
      ..cubicTo(12, size.height - 43, 10, 23, centerX, 8)
      ..cubicTo(size.width - 10, 23, size.width - 12, size.height - 43, centerX, pinBottom)
      ..close();

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, Paint()..color = const Color(0xFFE84C4C));

    canvas.drawCircle(Offset(centerX, 43), 14, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(centerX, 43), 7, Paint()..color = const Color(0xFFE84C4C));
  }

  static void drawTurnArrow(
    Canvas canvas,
    Size size, {
    required TurnDirection direction,
  }) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    if (direction == TurnDirection.straight) {
      path
        ..moveTo(center.dx - 12, size.height - 15)
        ..lineTo(center.dx - 12, 35)
        ..lineTo(23, 35)
        ..lineTo(center.dx, 10)
        ..lineTo(73, 35)
        ..lineTo(center.dx + 12, 35)
        ..lineTo(center.dx + 12, size.height - 15)
        ..close();
    } else if (direction == TurnDirection.left) {
      path
        ..moveTo(78, size.height - 16)
        ..lineTo(56, size.height - 16)
        ..lineTo(56, 49)
        ..cubicTo(56, 40, 49, 35, 39, 35)
        ..lineTo(31, 35)
        ..lineTo(31, 49)
        ..lineTo(10, 27)
        ..lineTo(31, 5)
        ..lineTo(31, 20)
        ..lineTo(40, 20)
        ..cubicTo(61, 20, 78, 33, 78, 51)
        ..close();
    } else if (direction == TurnDirection.right) {
      path
        ..moveTo(18, size.height - 16)
        ..lineTo(40, size.height - 16)
        ..lineTo(40, 49)
        ..cubicTo(40, 40, 47, 35, 57, 35)
        ..lineTo(65, 35)
        ..lineTo(65, 49)
        ..lineTo(86, 27)
        ..lineTo(65, 5)
        ..lineTo(65, 20)
        ..lineTo(56, 20)
        ..cubicTo(35, 20, 18, 33, 18, 51)
        ..close();
    } else {
      path
        ..moveTo(65, size.height - 13)
        ..lineTo(43, size.height - 13)
        ..lineTo(43, 54)
        ..cubicTo(43, 42, 51, 34, 62, 34)
        ..lineTo(70, 34)
        ..lineTo(70, 49)
        ..lineTo(89, 27)
        ..lineTo(70, 5)
        ..lineTo(70, 20)
        ..lineTo(61, 20)
        ..cubicTo(39, 20, 23, 35, 23, 55)
        ..lineTo(23, size.height - 13)
        ..lineTo(10, size.height - 13)
        ..lineTo(37, size.height - 2)
        ..close();
    }

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, Paint()..color = const Color(0xFF168A61));
  }
}
