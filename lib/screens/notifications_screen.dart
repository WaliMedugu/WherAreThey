import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notification_service.dart';
import '../data/notification_model.dart';
import 'sighting_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await _notificationService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
      // Mark all as read when the screen is opened
      await _notificationService.markAllAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notifications", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8A7650),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No notifications yet",
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          leading: CircleAvatar(
            backgroundColor: (notification.isRead ? Colors.grey[200] : const Color(0xFF8A7650).withOpacity(0.1)),
            child: Icon(
              _getIconForType(notification.type),
              color: notification.isRead ? Colors.grey : const Color(0xFF8A7650),
            ),
          ),
          title: Text(
            notification.title,
            style: GoogleFonts.outfit(
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: GoogleFonts.outfit(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDateTime(notification.createdAt),
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
          onTap: () {
            if (notification.type == 'sighting_report') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SightingDetailsScreen(notification: notification),
                ),
              );
            }
          },
        );
      },
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'case_status':
      case 'case_approval':
        return Icons.check_circle_outline;
      case 'case_denial':
        return Icons.error_outline;
      case 'sighting_report':
        return Icons.visibility_outlined;
      case 'comment':
        return Icons.comment_outlined;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}
