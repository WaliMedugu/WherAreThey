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

  static String slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '-')          // Spaces to dashes
        .replaceAll(RegExp(r'-+'), '-')           // Multiple dashes to one
        .trim();
  }

  static String getCaseUrl(Map<String, dynamic> person) {
    final name = person['name'] ?? 'unknown';
    final slug = slugify(name);
    return "https://wheraretheyng.vercel.app/case_$slug";
  }
}
