import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../data/notification_model.dart';

class SightingDetailsScreen extends StatefulWidget {
  final NotificationModel notification;

  const SightingDetailsScreen({super.key, required this.notification});

  @override
  State<SightingDetailsScreen> createState() => _SightingDetailsScreenState();
}

class _SightingDetailsScreenState extends State<SightingDetailsScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _finderProfile;
  Map<String, dynamic>? _caseData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final metadata = widget.notification.metadata;
      if (metadata == null) return;

      final finderId = metadata['finder_id'];
      final caseId = metadata['case_id'];

      // Fetch finder profile
      if (finderId != null) {
        final profileRes = await supabase
            .from('profiles')
            .select()
            .eq('id', finderId)
            .single();
        _finderProfile = profileRes;
      }

      // Fetch case data
      if (caseId != null) {
        final caseRes = await supabase
            .from('cases')
            .select()
            .eq('id', caseId)
            .single();
        _caseData = caseRes;
      }

    } catch (e) {
      debugPrint("Error loading sighting data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.notification.metadata;
    if (metadata == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Invalid notification data")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        title: Text("Sighting Report", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8A7650),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alert Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC0392B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFC0392B).withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B), size: 40),
                        const SizedBox(height: 12),
                        Text(
                          "Someone may have seen ${_caseData?['name'] ?? 'your reported person'}",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFC0392B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sighting Details Card
                  _buildSectionTitle("SIGHTING DETAILS"),
                  const SizedBox(height: 12),
                  _buildDetailsCard([
                    _buildDetailRow(Icons.location_on, "Where", metadata['location'] ?? "Unknown"),
                    _buildDetailRow(Icons.access_time, "When", metadata['time'] ?? "Unknown"),
                    _buildDetailRow(Icons.info_outline, "Details", metadata['details'] ?? "No extra details provided"),
                    _buildDetailRow(
                      Icons.people_outline,
                      "With them now?",
                      metadata['is_with_person'] == true ? "YES" : "NO",
                      isBold: true,
                      valueColor: metadata['is_with_person'] == true ? Colors.green : null,
                    ),
                  ]),
                  const SizedBox(height: 32),

                  // Finder Information
                  _buildSectionTitle("WHO REPORTED THIS?"),
                  const SizedBox(height: 12),
                  _buildFinderCard(),
                  const SizedBox(height: 48),

                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF8A7650),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDetailsCard(List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: const Color(0xFF8A7650).withOpacity(0.1),
                backgroundImage: NetworkImage('https://api.dicebear.com/7.x/identicon/png?seed=${_finderProfile?['id']}'),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _finderProfile?['full_name'] ?? "Unknown Finder",
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "VERIFIED SOURCE",
                        style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Divider(height: 1),
          ),
          _buildContactRow(Icons.email_outlined, "Email Address", _finderProfile?['email'] ?? "N/A"),
          const SizedBox(height: 16),
          _buildContactRow(Icons.phone_outlined, "Phone Number", _finderProfile?['phone'] ?? "N/A"),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF8A7650).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF8A7650), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              Text(
                value,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
