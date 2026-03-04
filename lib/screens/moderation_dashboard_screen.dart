import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ModerationDashboardScreen extends StatefulWidget {
  const ModerationDashboardScreen({super.key});

  @override
  State<ModerationDashboardScreen> createState() => _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState extends State<ModerationDashboardScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingCases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingCases();
  }

  Future<void> _fetchPendingCases() async {
    setState(() => _isLoading = true);
    try {
      // Fetch cases that are either pending OR have active reports
      final response = await supabase
          .from('cases')
          .select('*, case_reports(*)')
          .or('status.eq.pending,last_reported_at.not.is.null')
          .order('created_at', ascending: false);
      
      setState(() {
        _pendingCases = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching pending cases: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCaseStatus(String caseId, String status, {String? reason}) async {
    try {
      // Find the case in our list to get the reporter_id and person name
      final caseData = _pendingCases.firstWhere((c) => c['id'] == caseId);
      final reporterId = caseData['reporter_id'];
      final personName = caseData['name'] ?? "Unknown/Unconscious";

      await supabase
          .from('cases')
          .update({
            'status': status,
            'denial_reason': reason,
            'last_reported_at': null, // Clear report flag
          })
          .eq('id', caseId);
      
      // If approved, mark all pending reports for this case as reviewed
      if (status == 'active') {
        await supabase
            .from('case_reports')
            .update({'status': 'reviewed'})
            .eq('case_id', caseId)
            .eq('status', 'pending');
      }
      
      // Send notification to the reporter
      if (reporterId != null) {
        if (status == 'active') {
          await supabase.from('notifications').insert({
            'user_id': reporterId,
            'title': 'Case Approved',
            'message': 'Your case for "$personName" has been approved and is now active.',
            'type': 'case_approval',
          });
        } else if (status == 'denied') {
          await supabase.from('notifications').insert({
            'user_id': reporterId,
            'title': 'Case Denied',
            'message': 'Your case for "$personName" was not approved. Reason: ${reason ?? "No reason provided."}',
            'type': 'case_denial',
          });
        }
      }
      // Log the action to moderation_history
      final currentStatus = caseData['status'];
      await supabase.from('moderation_history').insert({
        'moderator_id': supabase.auth.currentUser?.id,
        'case_id': caseId,
        'action': status == 'active' ? (currentStatus == 'active' ? 'dismissed_reports' : 'approved') : 'denied',
        'reason': reason,
      });

      _fetchPendingCases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Case $status successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDenyDialog(String caseId) {
    String selectedReason = "";
    final customReasonController = TextEditingController();
    final List<String> commonReasons = [
      "Inappropriate content",
      "Incomplete details",
      "Duplicate report",
      "Low quality photos",
      "Inaccurate information",
      "Spam / Fake Case"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        "Deny Case Submission",
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF2D3436)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select a reason why this case is being rejected. This will be sent to the reporter.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: commonReasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return ChoiceChip(
                        label: Text(reason),
                        selected: isSelected,
                        onSelected: (val) {
                          setStateModal(() {
                            selectedReason = val ? reason : "";
                            if (val) customReasonController.clear();
                          });
                        },
                        selectedColor: Colors.red.shade100,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.red.shade800 : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(color: isSelected ? Colors.red.shade300 : Colors.transparent),
                        ),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Or provide a custom reason:",
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customReasonController,
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        setStateModal(() => selectedReason = "");
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "Enter custom reason...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (selectedReason.isEmpty && customReasonController.text.trim().isEmpty)
                              ? null
                              : () {
                                  final finalReason = selectedReason.isNotEmpty 
                                      ? selectedReason 
                                      : customReasonController.text.trim();
                                  Navigator.pop(context);
                                  _updateCaseStatus(caseId, 'denied', reason: finalReason);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text("Deny & Notify", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF8A7650),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    final displayValue = (value == null || (value is String && value.isEmpty)) ? "N/A" : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: displayValue),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return FutureBuilder(
      future: supabase
          .from('moderation_history')
          .select('*, cases(*)')
          .eq('moderator_id', supabase.auth.currentUser?.id ?? '')
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error loading history: ${snapshot.error}"));
        }
        final history = snapshot.data as List<dynamic>? ?? [];
        if (history.isEmpty) {
          return const Center(child: Text("No history found."));
        }

        return ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            final caseData = item['cases'];
            final action = item['action'];
            IconData actionIcon;
            Color color;
            
            if (action == 'approved') {
              actionIcon = Icons.check_circle;
              color = Colors.green;
            } else if (action == 'denied') {
              actionIcon = Icons.cancel;
              color = Colors.red;
            } else {
              actionIcon = Icons.visibility_off;
              color = Colors.orange;
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(
                    actionIcon,
                    color: color,
                  ),
                ),
                title: Text(caseData?['name'] ?? "Unknown Case", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Action: ${action.toString().toUpperCase()}"),
                    if (item['reason'] != null)
                      Text("Reason: ${item['reason']}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    Text(
                      "Date: ${DateTime.parse(item['created_at']).toLocal().toString().split('.')[0]}",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Moderation Dashboard", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF8A7650),
          elevation: 0,
          actions: [
            IconButton(onPressed: _fetchPendingCases, icon: const Icon(Icons.refresh)),
          ],
          bottom: TabBar(
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal),
            labelColor: const Color(0xFF8A7650),
            indicatorColor: const Color(0xFF8A7650),
            tabs: const [
              Tab(text: "Pending Queue"),
              Tab(text: "My History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _pendingCases.isEmpty
                ? const Center(child: Text("No pending cases to review."))
                : ListView.builder(
                    itemCount: _pendingCases.length,
                    itemBuilder: (context, index) {
                      final caseData = _pendingCases[index];
                      final isUnconscious = caseData['is_unconscious'] ?? false;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            backgroundImage: NetworkImage('https://api.dicebear.com/7.x/identicon/png?seed=${caseData['reporter_id']}'),
                          ),
                          title: Row(
                            children: [
                              Text(caseData['name'] ?? "Unknown/Unconscious"),
                              if (caseData['last_reported_at'] != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "REPORTED",
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text("Reported by ${caseData['reporter_full_name']} • ${caseData['reporter_relationship']}"),
                          trailing: const Icon(Icons.info_outline),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (caseData['case_reports'] != null && (caseData['case_reports'] as List).isNotEmpty) ...[
                                    _buildSectionTitle("REPORTS"),
                                    ...(caseData['case_reports'] as List).where((r) => r['status'] == 'pending').map((report) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.withOpacity(0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              report['reason'] ?? "No reason",
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                                            ),
                                            if (report['details'] != null && report['details'].isNotEmpty)
                                              Text(report['details'], style: const TextStyle(fontSize: 13)),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Reported on: ${DateTime.parse(report['created_at']).toLocal().toString().split('.')[0]}",
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )),
                                    const SizedBox(height: 16),
                                  ],
                                  // 1. Identity
                                  _buildSectionTitle("IDENTITY"),
                                  _buildInfoRow("Full Name", caseData['name'] ?? "Unknown"),
                                  _buildInfoRow("Aliases", (caseData['aliases'] as List?)?.join(', ') ?? 'None'),
                                  _buildInfoRow("DOB", caseData['dob'] ?? (caseData['dob_unknown'] == true ? 'Unknown' : 'N/A')),
                                  if (caseData['age_primary'] != null)
                                    _buildInfoRow("Age range", "${caseData['age_primary']} / ${caseData['age_secondary'] ?? 'N/A'}"),
                                  _buildInfoRow("Gender", caseData['gender'] ?? 'Unknown'),
                                  _buildInfoRow("Nationality", caseData['nationality'] ?? 'N/A'),
                                  _buildInfoRow("State of Origin", caseData['state_of_origin'] ?? 'N/A'),
                                  _buildInfoRow("Tribe", caseData['tribe'] ?? 'N/A'),
                                  _buildInfoRow("Languages", (caseData['languages_spoken'] as List?)?.join(', ') ?? 'N/A'),
                                  
                                  const SizedBox(height: 16),
                                  // 2. Physical
                                  _buildSectionTitle("PHYSICAL DESCRIPTION"),
                                  _buildInfoRow("Height", caseData['height'] ?? (caseData['height_unknown'] == true ? 'Unknown' : 'N/A')),
                                  _buildInfoRow("Build", caseData['build'] ?? 'N/A'),
                                  _buildInfoRow("Skin Tone", caseData['skin_tone'] ?? 'N/A'),
                                  _buildInfoRow("Eye Color", caseData['eye_color'] ?? 'N/A'),
                                  _buildInfoRow("Hair", (caseData['hair_description'] as List?)?.join(', ') ?? 'N/A'),
                                  _buildInfoRow("Marks", (caseData['distinguishing_marks'] as List?)?.join(', ') ?? 'N/A'),
                                  _buildInfoRow("Clothing", (caseData['last_clothing'] as List?)?.join(', ') ?? 'N/A'),
      
                                  const SizedBox(height: 16),
                                  // 3. Disappearance
                                  _buildSectionTitle("DISAPPEARANCE DETAILS"),
                                  _buildInfoRow("Date seen", "${caseData['date_last_seen'] ?? 'Unknown'}${caseData['date_is_approximate'] == true ? ' (Approximate)' : ''}"),
                                  _buildInfoRow("Time seen", caseData['time_last_seen'] ?? 'Unknown'),
                                  _buildInfoRow("Location", "${caseData['state_last_seen'] ?? 'Unknown'}${caseData['lga_last_seen'] != null ? ', ${caseData['lga_last_seen']}' : ''}"),
                                  _buildInfoRow("Description", (caseData['location_description'] as List?)?.join(', ') ?? 'N/A'),
                                  _buildInfoRow("Circumstances", caseData['circumstances'] ?? 'N/A'),
                                  _buildInfoRow("Occupation", caseData['occupation_school'] ?? 'N/A'),
                                  _buildInfoRow("Medical", (caseData['medical_conditions'] as List?)?.join(', ') ?? 'None'),
                                  _buildInfoRow("Police Ref", caseData['police_reference'] ?? 'N/A'),
      
                                  if (caseData['photos'] != null && (caseData['photos'] as List).isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _buildSectionTitle("PHOTOS"),
                                    SizedBox(
                                      height: 120,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: (caseData['photos'] as List).length,
                                        itemBuilder: (context, i) {
                                          final photoPath = caseData['photos'][i].toString();
                                          final imageUrl = supabase.storage.from('case_photos').getPublicUrl(photoPath);
                                          
                                          return GestureDetector(
                                            onTap: () => _showFullScreenImage(imageUrl),
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 12.0),
                                              child: Hero(
                                                tag: imageUrl,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: Colors.grey[300]!),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Image.network(
                                                      imageUrl,
                                                      width: 120,
                                                      height: 120,
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context, child, loadingProgress) {
                                                        if (loadingProgress == null) return child;
                                                        return Container(
                                                          width: 120,
                                                          height: 120,
                                                          color: Colors.grey[100],
                                                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                        );
                                                      },
                                                      errorBuilder: (context, error, stackTrace) => Container(
                                                        width: 120,
                                                        height: 120,
                                                        color: Colors.grey[200],
                                                        child: const Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(Icons.broken_image, color: Colors.grey, size: 30),
                                                            SizedBox(height: 4),
                                                            Text("Image error", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
      
                                  const SizedBox(height: 16),
                                  // 4. Contact
                                  _buildSectionTitle("CONTACT INFORMATION"),
                                  _buildInfoRow("Reporter", caseData['reporter_full_name'] ?? 'N/A'),
                                  _buildInfoRow("Phone", caseData['reporter_phone'] ?? 'N/A'),
                                  _buildInfoRow("Email", caseData['reporter_email'] ?? 'N/A'),
                                  _buildInfoRow("Relationship", caseData['reporter_relationship'] ?? 'N/A'),
                                  _buildInfoRow("Type", caseData['reported_by_type'] ?? 'N/A'),
                                  if (caseData['secondary_contact_name'] != null && caseData['secondary_contact_name'].isNotEmpty) ...[
                                    _buildInfoRow("Secondary", caseData['secondary_contact_name']),
                                    _buildInfoRow("Sec. Phone", caseData['secondary_contact_phone']),
                                  ],
      
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => _showDenyDialog(caseData['id']),
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text("DENY & REMOVE"),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton(
                                        onPressed: () => _updateCaseStatus(caseData['id'], 'active'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                        child: Text(caseData['status'] == 'active' ? "DISMISS REPORTS" : "APPROVE & POST"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }
}
