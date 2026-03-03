import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/notification_model.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  Future<List<NotificationModel>> getNotifications({int limit = 50}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => NotificationModel.fromJson(data))
          .toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<List<NotificationModel>> getRecentNotifications({int limit = 3}) async {
    return getNotifications(limit: limit);
  }

  Future<int> getUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      
      return (response as List).length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String message,
    String? type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': targetUserId,
        'title': title,
        'message': message,
        'type': type,
        'metadata': metadata,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Stream<List<NotificationModel>> subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => NotificationModel.fromJson(json)).toList());
  }
}
