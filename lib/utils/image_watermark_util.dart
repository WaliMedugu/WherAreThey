import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ImageWatermarkUtil {
  static Future<Uint8List?> addWatermark({
    required Uint8List imageBytes,
    required String name,
    required String date,
    required String location,
    required String time,
    required String contact,
  }) async {
    try {
      // 1. Decode Original Image
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image original = frameInfo.image;

      // 2. Setup Canvas
      const double targetWidth = 1200;
      const double targetHeight = 1600;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, targetWidth, targetHeight));

      // 3. Draw Background (Blurred Cover)
      double bgScaleW = targetWidth / original.width;
      double bgScaleH = targetHeight / original.height;
      double bgScale = bgScaleW > bgScaleH ? bgScaleW : bgScaleH;
      
      double bgW = original.width * bgScale;
      double bgH = original.height * bgScale;
      double bgX = (targetWidth - bgW) / 2;
      double bgY = (targetHeight - bgH) / 2;

      final bgPaint = Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30)
        ..color = Color.fromRGBO(255, 255, 255, 1);
      
      canvas.drawImageRect(
        original, 
        Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
        Rect.fromLTWH(bgX, bgY, bgW, bgH),
        bgPaint
      );

      // Darken overlay
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, targetWidth, targetHeight),
        Paint()..color = const Color.fromRGBO(0, 0, 0, 0.4)
      );

      // 4. Draw Foreground (Contain)
      double fgScaleW = targetWidth / original.width;
      double fgScaleH = targetHeight / original.height;
      double fgScale = fgScaleW < fgScaleH ? fgScaleW : fgScaleH;
      
      double fgW = original.width * fgScale;
      double fgH = original.height * fgScale;
      double fgX = (targetWidth - fgW) / 2;
      double fgY = (targetHeight - fgH) / 2;

      canvas.drawImageRect(
        original,
        Rect.fromLTWH(0, 0, original.width.toDouble(), original.height.toDouble()),
        Rect.fromLTWH(fgX, fgY, fgW, fgH),
        Paint(),
      );

      // 5. Draw Info Bar
      const double barHeight = 400; // More space for dynamic content
      final barRect = const Rect.fromLTWH(0, targetHeight - barHeight, targetWidth, barHeight);
      final barPaint = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.85);
      canvas.drawRect(barRect, barPaint);

      // 6. Draw Text using Playfair Display Bold
      final boldFont = GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold).fontFamily;
      double currentY = targetHeight - barHeight + 40;
      
      void drawTextDynamic(String text, double fontSize, Color color, {double maxW = 1120}) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: boldFont,
              letterSpacing: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: maxW);
        textPainter.paint(canvas, Offset(40, currentY));
        currentY += textPainter.height + 12;
      }

      drawTextDynamic("MISSING PERSON ALERT", 32, const Color(0xFFDBCEA5));
      currentY += 5; // Extra gap
      drawTextDynamic("NAME: ${name.toUpperCase()}", 48, Colors.white);
      drawTextDynamic("LAST SEEN: $date", 36, Colors.white);
      drawTextDynamic("LOCATION: $location ($time)", 36, Colors.white);
      
      // Make contact line slightly shorter in width to avoid the logo
      drawTextDynamic("CONTACT: $contact", 42, const Color(0xFFFFD700), maxW: 850);

      // 7. Footer site name (Very small and absolute at the bottom)
      final footerPainter = TextPainter(
        text: TextSpan(
           text: "WWW.WHERARETHEY.APP",
           style: TextStyle(
             color: const Color(0xFF808080),
             fontSize: 20,
             fontWeight: FontWeight.bold,
             fontFamily: boldFont,
           ),
        ),
        textDirection: TextDirection.ltr,
      );
      footerPainter.layout();
      footerPainter.paint(canvas, Offset(40, targetHeight - footerPainter.height - 20));

      // 8. Draw Logo (Circular, Topmost Layer)
      final ByteData logoData = await rootBundle.load('assets/logo.png');
      final ui.Codec logoCodec = await ui.instantiateImageCodec(logoData.buffer.asUint8List());
      final ui.FrameInfo logoFrame = await logoCodec.getNextFrame();
      final ui.Image logo = logoFrame.image;

      const double logoSize = 180;
      final double logoX = targetWidth - logoSize - 40;
      final double logoY = targetHeight - logoSize - 50;
      final logoRect = Rect.fromLTWH(logoX, logoY, logoSize, logoSize);

      canvas.save();
      canvas.clipPath(Path()..addOval(logoRect));
      canvas.drawImageRect(
        logo,
        Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
        logoRect,
        Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();

      // Border for logo 
      canvas.drawOval(
        logoRect,
        Paint()
          ..color = const Color(0xFFDBCEA5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );

      // 9. Convert to Bytes
      final picture = recorder.endRecording();
      final img = await picture.toImage(targetWidth.toInt(), targetHeight.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();

    } catch (e) {
      debugPrint("Watermark error: $e");
      return null;
    }
  }
}
