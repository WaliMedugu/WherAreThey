import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .order('full_name', ascending: true);
      
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching users: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await supabase
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId);
      
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User updated to $newRole")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRoleManagementDialog(Map<String, dynamic> user) {
    final currentRole = user['role'];
    final userId = user['id'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Manage Role: ${user['full_name'] ?? 'User'}",
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              if (currentRole == 'user')
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.blue),
                  title: const Text("Promote to Moderator"),
                  onTap: () {
                    Navigator.pop(context);
                    _updateUserRole(userId, 'moderator');
                  },
                ),
              
              if (currentRole == 'moderator') ...[
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                  title: const Text("Promote to Admin"),
                  onTap: () {
                    Navigator.pop(context);
                    _updateUserRole(userId, 'admin');
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage('https://api.dicebear.com/7.x/identicon/png?seed=${userId}'),
                  ),
                  title: const Text("Demote to User"),
                  onTap: () {
                    Navigator.pop(context);
                    _updateUserRole(userId, 'user');
                  },
                ),
              ],
              
              if (currentRole == 'admin' && user['id'] != supabase.auth.currentUser?.id)
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.blue),
                  title: const Text("Demote to Moderator"),
                  onTap: () {
                    Navigator.pop(context);
                    _updateUserRole(userId, 'moderator');
                  },
                ),
              
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((user) {
      final name = (user['full_name'] ?? '').toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || email.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Panel", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8A7650),
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchUsers, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search by name or email...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredUsers.isEmpty
                ? Center(child: Text("No users found", style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final role = user['role'];
                      Color roleColor;
                      switch (role) {
                        case 'admin': roleColor = Colors.purple; break;
                        case 'moderator': roleColor = Colors.blue; break;
                        default: roleColor = Colors.grey;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: roleColor.withOpacity(0.1),
                            backgroundImage: NetworkImage('https://api.dicebear.com/7.x/identicon/png?seed=${user['id']}'),
                          ),
                          title: Text(user['full_name'] ?? 'Incomplete Profile', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['email'] ?? 'No email available'),
                              const SizedBox(height: 4),
                              Text(
                                "Joined: ${user['created_at'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(user['created_at'])) : 'Unknown'}",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onTap: () => _showRoleManagementDialog(user),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
