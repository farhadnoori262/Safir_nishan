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

  /// متد جدید جهت رسم تابلوی کپسولی کامل (آیکون پیچ + اسم خیابان) با تم سبز پروژه
  static void drawStepBanner(
    Canvas canvas,
    Size size, {
    required String streetName,
    required TurnDirection direction,
  }) {
    const double paddingX = 20.0;
    const double bannerHeight = 64.0;
    const double borderRadius = 32.0;
    const double triangleHeight = 12.0;

    final center = Offset(size.width / 2, size.height / 2);

    // ۱. آماده‌سازی متن
    final textPainter = TextPainter(
      text: TextSpan(
        text: streetName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'IRANSans', // یا فونت پروژه شما
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    final double bannerWidth = textPainter.width + 100.0;
    final double left = center.dx - (bannerWidth / 2);
    final double top = center.dy - (bannerHeight / 2) - (triangleHeight / 2);
    final double right = left + bannerWidth;
    final double bottom = top + bannerHeight;

    final bannerRect = RRect.fromLTRBR(
      left,
      top,
      right,
      bottom,
      const Radius.circular(borderRadius),
    );

    // ۲. مسیر تابلوی کپسولی + مثلث پایین (پین)
    final path = Path()..addRRect(bannerRect);

    final trianglePath = Path()
      ..moveTo(center.dx - 12, bottom - 2)
      ..lineTo(center.dx, bottom + triangleHeight)
      ..lineTo(center.dx + 12, bottom - 2)
      ..close();

    final fullPath = Path.combine(PathOperation.union, path, trianglePath);

    // سایه تابلو
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(fullPath.shift(const Offset(0, 4)), shadowPaint);

    // پس‌زمینه اصلی سبز
    final bgPaint = Paint()
      ..color = const Color(0xFF07553D)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fullPath, bgPaint);

    // حاشیه سفید نازک دور تابلو
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(fullPath, borderPaint);

    // ۳. رسم متن خیابان
    final textOffset = Offset(
      left + paddingX + 36,
      top + (bannerHeight - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    // ۴. رسم آیکون فلش سفید در سمت راست تابلو
    canvas.save();
    final iconCenter = Offset(right - paddingX - 18, top + (bannerHeight / 2));
    canvas.translate(iconCenter.dx - 20, iconCenter.dy - 20);

    _drawInnerWhiteArrow(canvas, const Size(40, 40), direction);
    canvas.restore();
  }

  /// آیکون فلش تک‌رنگ سفید برای داخل تابلو
  static void _drawInnerWhiteArrow(Canvas canvas, Size size, TurnDirection direction) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);

    if (direction == TurnDirection.left) {
      path
        ..moveTo(center.dx - 10, center.dy - 12)
        ..lineTo(center.dx - 20, center.dy)
        ..lineTo(center.dx - 10, center.dy + 12)
        ..lineTo(center.dx - 10, center.dy + 4)
        ..lineTo(center.dx + 10, center.dy + 4)
        ..cubicTo(center.dx + 14, center.dy + 4, center.dx + 16, center.dy - 2, center.dx + 16, center.dy - 6)
        ..lineTo(center.dx + 10, center.dy - 6)
        ..lineTo(center.dx - 10, center.dy - 6)
        ..close();
    } else if (direction == TurnDirection.right) {
      path
        ..moveTo(center.dx + 10, center.dy - 12)
        ..lineTo(center.dx + 20, center.dy)
        ..lineTo(center.dx + 10, center.dy + 12)
        ..lineTo(center.dx + 10, center.dy + 4)
        ..lineTo(center.dx - 10, center.dy + 4)
        ..cubicTo(center.dx - 14, center.dy + 4, center.dx - 16, center.dy - 2, center.dx - 16, center.dy - 6)
        ..lineTo(center.dx - 10, center.dy - 6)
        ..lineTo(center.dx + 10, center.dy - 6)
        ..close();
    } else {
      path
        ..moveTo(center.dx, center.dy - 16)
        ..lineTo(center.dx - 12, center.dy + 2)
        ..lineTo(center.dx - 4, center.dy + 2)
        ..lineTo(center.dx - 4, center.dy + 14)
        ..lineTo(center.dx + 4, center.dy + 14)
        ..lineTo(center.dx + 4, center.dy + 2)
        ..lineTo(center.dx + 12, center.dy + 2)
        ..close();
    }

    canvas.drawPath(path, paint);
  }

  /// نشانگر موقعیت فعلی (مبدا) — طرح آبی استاندارد GPS با هاله‌ی دقت
  /// و موج پویا. اندازه‌ی بزرگ‌تر برای دیده‌شدن بهتر روی نقشه.
  static void drawCurrentLocationPulse(
    Canvas canvas,
    Size size,
    double pulseValue,
    double currentAccuracy,
  ) {
    const Color gpsBlue = Color(0xFF1A73E8);

    final center = Offset(size.width / 2, size.height / 2);
    final baseAccuracyRadius = currentAccuracy.clamp(20.0, 75.0);

    // هاله‌ی ثابت دقت GPS — همیشه نمایان است، نه فقط در حال پالس
    canvas.drawCircle(
      center,
      baseAccuracyRadius,
      Paint()
        ..color = gpsBlue.withOpacity(0.14)
        ..style = PaintingStyle.fill,
    );

    // موج پویا (پالس) که به بیرون گسترش می‌یابد و محو می‌شود
    final animatedRadius = baseAccuracyRadius * (0.4 + (0.6 * pulseValue));
    final pulseOpacity = (0.30 * (1.0 - pulseValue)).clamp(0.0, 0.30);

    canvas.drawCircle(
      center,
      animatedRadius,
      Paint()
        ..color = gpsBlue.withOpacity(pulseOpacity)
        ..style = PaintingStyle.fill,
    );

    // سایه‌ی زیر دایره مرکزی برای عمق بصری
    canvas.drawCircle(
      center,
      17,
      Paint()
        ..color = Colors.black.withOpacity(0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // حلقه‌ی سفید ضخیم دور نقطه مرکزی (بزرگ‌تر از قبل)
    canvas.drawCircle(center, 15, Paint()..color = Colors.white);

    // نقطه‌ی مرکزی آبی — رنگ استاندارد نشانگر موقعیت GPS
    canvas.drawCircle(center, 10, Paint()..color = gpsBlue);
  }

  /// آیکون فلش راننده - این تابع در حال حاضر مستقیم استفاده نمی‌شود
  /// (فلش واقعی از فایل navigation_arrow.png بارگذاری می‌شود)
  static void drawDriverArrow(Canvas canvas, Size size) {
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

    final center = Offset(size.width / 2, size.height / 2);
    const double tipOffsetY = 8.0;
    const double bottomOffsetY = 19.0;
    const double notchOffsetY = 15.0;
    const double sideOffsetX = 27.0;
    const double edgeOffsetX = 18.0;

    final path = Path()
      ..moveTo(center.dx, tipOffsetY)
      ..lineTo(size.width - edgeOffsetX, size.height - bottomOffsetY)
      ..quadraticBezierTo(
        size.width - (edgeOffsetX - 2),
        size.height - 10,
        size.width - sideOffsetX,
        size.height - notchOffsetY,
      )
      ..lineTo(center.dx, size.height - 35)
      ..lineTo(sideOffsetX, size.height - notchOffsetY)
      ..quadraticBezierTo(
        edgeOffsetX - 2,
        size.height - 10,
        edgeOffsetX,
        size.height - bottomOffsetY,
      )
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
    canvas.drawPath(path, Paint()..color = AppColors.primaryButton);
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
    canvas.drawPath(path, Paint()..color = AppColors.primaryBrand);
  }
}
