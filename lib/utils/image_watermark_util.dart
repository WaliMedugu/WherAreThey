import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class ImageWatermarkUtil {
  static Future<Uint8List?> addWatermark({
    required Uint8List imageBytes,
    required String location,
    required String contact,
  }) async {
    try {
      // Decode the main image
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Load logo from assets
      final ByteData logoData = await rootBundle.load('assets/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final logo = img.decodeImage(logoBytes);
      if (logo == null) return null;

      // Resize logo to be "tiny" (e.g., 8% of image width)
      final logoWidth = (image.width * 0.08).toInt().clamp(40, 100);
      final resizedLogo = img.copyResize(logo, width: logoWidth, interpolation: img.Interpolation.average);

      // Create a background bar at the bottom for readability
      final barHeight = 80;
      img.fillRect(
        image, 
        x1: 0, 
        y1: image.height - barHeight, 
        x2: image.width, 
        y2: image.height, 
        color: img.ColorRgba8(0, 0, 0, 160)
      );

      // Draw logo on the bottom right
      final logoX = image.width - resizedLogo.width - 20;
      final logoY = image.height - resizedLogo.height - 15;
      img.compositeImage(image, resizedLogo, dstX: logoX, dstY: logoY);

      // Draw text
      final text = "Last seen: $location\nContact: $contact";
      final font = img.arial24; // Standard fallback
      
      img.drawString(
        image, 
        text, 
        font: font, 
        x: 20, 
        y: image.height - barHeight + 15, 
        color: img.ColorRgb8(255, 255, 255)
      );

      // Add "WherAreThey" branding
      img.drawString(
        image, 
        "WWW.WHERARETHEY.APP", 
        font: img.arial14, 
        x: 20, 
        y: image.height - 20, 
        color: img.ColorRgb8(200, 200, 200)
      );

      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      print("Watermark error: $e");
      return null;
    }
  }
}
