import 'dart:js' as js;

class SeoUtil {
  static void updateMeta({
    required String title,
    required String description,
  }) {
    try {
      js.context.callMethod('updateMeta', [title, description]);
    } catch (e) {
      // Fallback or ignore if not on web
    }
  }
}
