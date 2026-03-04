import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'admin_dashboard_screen.dart';
import 'moderation_dashboard_screen.dart';
import 'report_case_screen.dart';
import 'notifications_screen.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../data/notification_model.dart';
import 'package:universal_html/html.dart' as html;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;
  String? _role;
  List<dynamic> _userCases = [];
  List<NotificationModel> _recentNotifications = [];
  final User? _user = Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', _user?.id as Object)
          .single();
      
      setState(() {
        _nameController.text = response['full_name'] ?? '';
        _role = response['role'];
      });
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    _fetchUserCases();
    _fetchRecentNotifications();
  }

  Future<void> _fetchRecentNotifications() async {
    try {
      final notifications = await _notificationService.getRecentNotifications();
      if (mounted) {
        setState(() {
          _recentNotifications = notifications;
        });
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    }
  }

  Future<void> _fetchUserCases() async {
    try {
      final response = await Supabase.instance.client
          .from('cases')
          .select()
          .eq('reporter_id', _user?.id as Object)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _userCases = response as List;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user cases: $e");
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'full_name': _nameController.text.trim()})
          .eq('id', _user?.id as Object);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCase(String caseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Case?"),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('cases').delete().eq('id', caseId);
        _fetchUserCases();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case deleted.")));
      } catch (e) {
        debugPrint("Error deleting case: $e");
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Account?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
          "This action is permanent and cannot be undone. All your reported cases and profile information will be deleted forever.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete Everything"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client.rpc('delete_user_account');
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account deleted successfully.")),
          );
          context.go('/auth');
          html.window.location.reload();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Deletion failed: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Account", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8A7650),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                context.go('/auth');
                html.window.location.reload();
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: "Sign Out",
          ),
        ],
      ),
      body: _isLoading 
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFF8A7650).withOpacity(0.1),
                      backgroundImage: NetworkImage('https://api.dicebear.com/7.x/identicon/png?seed=${_user?.id}'),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user?.email ?? "Unknown User",
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: (_role == 'admin' ? Colors.purple : _role == 'moderator' ? Colors.blue : Colors.grey).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (_role ?? 'user').toUpperCase(),
                              style: TextStyle(
                                color: _role == 'admin' ? Colors.purple : _role == 'moderator' ? Colors.blue : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Account Details Section
                Text("Information", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            border: UnderlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Email Address"),
                          subtitle: Text(_user?.email ?? 'N/A'),
                          trailing: const Icon(Icons.lock_outline, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),

                // Notifications Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Recent Notifications", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => context.push('/notifications').then((_) => _fetchRecentNotifications()),
                      child: const Text("View All", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_recentNotifications.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text("No notifications yet", style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentNotifications.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final n = _recentNotifications[index];
                        return ListTile(
                          leading: Icon(
                            n.isRead ? Icons.notifications_none : Icons.notifications_active,
                            color: n.isRead ? Colors.grey : const Color(0xFF8A7650),
                            size: 20,
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            n.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => context.push('/notifications').then((_) => _fetchRecentNotifications()),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 32),
                
                // My Reports Section (Dashboard)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("My Reports", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("${_userCases.length} Total", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                if (_userCases.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_late_outlined, color: Colors.grey[400], size: 40),
                        const SizedBox(height: 12),
                        const Text("You haven't reported any cases yet.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userCases.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = _userCases[index];
                      final status = c['status'] as String;
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          title: Text(c['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Reported on ${c['created_at'].toString().split('T')[0]}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (status == 'active' || status == 'found' ? Colors.green : status == 'pending' ? Colors.orange : Colors.red).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'active' || status == 'found' ? Colors.green : status == 'pending' ? Colors.orange : Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    context.push('/report?id=${c['id']}').then((_) => _fetchUserCases());
                                  } else if (value == 'delete') {
                                    _deleteCase(c['id']);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (status != 'found')
                                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A7650),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Changes"),
                  ),
                ),

                if (_role == 'admin') ...[
                  const SizedBox(height: 40),
                  Text("Management", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                      title: const Text("Admin Dashboard"),
                      subtitle: const Text("Manage user roles and permissions"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/admin'),
                    ),
                  ),
                ],

                if (_role == 'admin' || _role == 'moderator') ...[
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.fact_check, color: Colors.blue),
                      title: const Text("Moderation Dashboard"),
                      subtitle: const Text("Review and approve pending cases"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/moderation'),
                    ),
                  ),
                ],

                const SizedBox(height: 80),
                
                // Danger Zone
                Text("Danger Zone", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 16),
                Card(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Remove all your data and reports forever."),
                    trailing: const Icon(Icons.chevron_right, color: Colors.red),
                    onTap: _deleteAccount,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
