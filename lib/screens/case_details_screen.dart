import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CaseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> person;

  const CaseDetailsScreen({super.key, required this.person});

  @override
  State<CaseDetailsScreen> createState() => _CaseDetailsScreenState();
}

class _CaseDetailsScreenState extends State<CaseDetailsScreen> {
  bool _isNumberRevealed = false;
  bool _isCheckingSighting = true;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyReported();
  }

  Future<void> _checkIfAlreadyReported() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isCheckingSighting = false);
      return;
    }

    try {
      // Check if this user has already reported a sighting for this case
      // We search across all notifications since metadata contains finder_id
      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('type', 'sighting_report')
          .filter('metadata->>case_id', 'eq', widget.person['id'])
          .filter('metadata->>finder_id', 'eq', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() => _isNumberRevealed = true);
      }
    } catch (e) {
      debugPrint("Error checking previous reports: $e");
    } finally {
      if (mounted) setState(() => _isCheckingSighting = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _markAsFound() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.home_rounded, color: Colors.green, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  "They're coming home.",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3436),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Marking this case as Found will remove it from the public feed immediately. Your information will be kept securely for 365 days, then permanently deleted.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  "Are you ready to close this case?",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: const Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text("Not yet", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Yes, Close Case", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdatingStatus = true);

    try {
      await Supabase.instance.client
          .from('cases')
          .update({
            'status': 'found',
            'found_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.person['id']);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite, color: Colors.red, size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "They're home.",
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "We are so relieved for you and everyone who never stopped searching.",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3436)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "This case has been marked as Found and removed from the public feed.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A7650).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF8A7650).withOpacity(0.1)),
                      ),
                      child: Text(
                        "If this platform played any part in bringing them back to you, that is exactly why it exists.",
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF8A7650),
                          fontStyle: FontStyle.italic,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Spread the word, let's find more people",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, 
                        color: Colors.green.shade700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Pop dialog
                          Navigator.pop(context, true); // Pop screen and signal refresh
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A7650),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update status: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 800;
    final photos = widget.person['photos'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: isDesktop ? 400 : 300,
            pinned: true,
            backgroundColor: const Color(0xFF8A7650),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.person['name'] ?? 'Unknown',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (photos.isNotEmpty)
                    Image.network(
                      'https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/${photos[0]}',
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: const Color(0xFF8A7650),
                      child: const Icon(Icons.person, size: 100, color: Colors.white54),
                    ),
                  // Gradient Overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? size.width * 0.15 : 20,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusBadge(widget.person['status']),
                      if (widget.person['reporter_id'] == Supabase.instance.client.auth.currentUser?.id && widget.person['status'] == 'active')
                        _isUpdatingStatus 
                          ? const CircularProgressIndicator()
                          : TextButton.icon(
                              onPressed: _markAsFound,
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              label: const Text("FOUND MY LOVED ONE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.green.withOpacity(0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick Info Grid
                  Row(
                    children: [
                      _buildQuickInfoItem(Icons.calendar_today, "Last Seen", _formatDate(widget.person['date_last_seen'])),
                      const SizedBox(width: 16),
                      _buildQuickInfoItem(Icons.location_on, "Location", widget.person['state_last_seen'] ?? 'Unknown'),
                      const SizedBox(width: 16),
                      _buildQuickInfoItem(Icons.person_outline, "Gender", widget.person['gender'] ?? 'Unknown'),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Photo Gallery
                  if (photos.length > 1) ...[
                    _buildSectionTitle("Photos"),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          final imageUrl = 'https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/${photos[index]}';
                          return GestureDetector(
                            onTap: () => _showFullScreenImage(context, imageUrl),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Identity Section
                  _buildSectionCard(
                    title: "Identity Information",
                    icon: Icons.badge_outlined,
                    children: [
                      _buildDetailRow("Full Name", widget.person['name'] ?? 'Unknown'),
                      _buildDetailRow("Aliases", (widget.person['aliases'] as List?)?.join(', ') ?? 'None'),
                      _buildDetailRow("Date of Birth", widget.person['dob'] ?? (widget.person['dob_unknown'] == true ? 'Unknown' : 'N/A')),
                      if (widget.person['age_primary'] != null)
                        _buildDetailRow("Age Estimates", "${widget.person['age_primary']} / ${widget.person['age_secondary'] ?? ''}"),
                      _buildDetailRow("Nationality", widget.person['nationality'] ?? 'N/A'),
                      _buildDetailRow("State of Origin", widget.person['state_of_origin'] ?? 'N/A'),
                      _buildDetailRow("Tribe", widget.person['tribe'] ?? 'N/A'),
                      _buildDetailRow("Languages", (widget.person['languages_spoken'] as List?)?.join(', ') ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Physical Description
                  _buildSectionCard(
                    title: "Physical Description",
                    icon: Icons.accessibility_new,
                    children: [
                      _buildDetailRow("Height", widget.person['height'] ?? (widget.person['height_unknown'] == true ? 'Unknown' : 'N/A')),
                      _buildDetailRow("Build", widget.person['build'] ?? 'N/A'),
                      _buildDetailRow("Skin Tone", widget.person['skin_tone'] ?? 'N/A'),
                      _buildDetailRow("Eye Color", widget.person['eye_color'] ?? 'N/A'),
                      _buildDetailRow("Hair", (widget.person['hair_description'] as List?)?.join(', ') ?? 'N/A'),
                      _buildDetailRow("Distinguishing Marks", (widget.person['distinguishing_marks'] as List?)?.join(', ') ?? 'None'),
                      _buildDetailRow("Last Known Clothing", (widget.person['last_clothing'] as List?)?.join(', ') ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Disappearance Details
                  _buildSectionCard(
                    title: "Disappearance Details",
                    icon: Icons.history,
                    children: [
                      _buildDetailRow("Last Seen Date", "${_formatDate(widget.person['date_last_seen'])}${widget.person['date_is_approximate'] == true ? ' (Approximate)' : ''}"),
                      _buildDetailRow("Last Seen Time", widget.person['time_last_seen'] ?? 'Unknown'),
                      _buildDetailRow("LGA", widget.person['lga_last_seen'] ?? 'N/A'),
                      _buildDetailRow("State", widget.person['state_last_seen'] ?? 'Unknown'),
                      _buildDetailRow("Location Description", (widget.person['location_description'] as List?)?.join(', ') ?? 'N/A'),
                      _buildDetailRow("Circumstances", widget.person['circumstances'] ?? 'N/A'),
                      _buildDetailRow("Occupation/School", widget.person['occupation_school'] ?? 'N/A'),
                      _buildDetailRow("Medical Conditions", (widget.person['medical_conditions'] as List?)?.join(', ') ?? 'None'),
                      _buildDetailRow("Police Reference", widget.person['police_reference'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Contact Information
                  _buildSectionCard(
                    title: "Contact Information",
                    icon: Icons.contact_phone_outlined,
                    children: [
                      _buildDetailRow("Reported By", widget.person['reporter_full_name'] ?? 'N/A'),
                      _buildDetailRow("Relationship", widget.person['reporter_relationship'] ?? 'N/A'),
                      _buildDetailRow(
                        "Contact Phone", 
                        _isNumberRevealed 
                            ? widget.person['reporter_phone'] ?? 'N/A' 
                            : "•••• •••• •••• (Hidden)"
                      ),
                      _buildDetailRow(
                        "Contact Email", 
                        _isNumberRevealed 
                            ? widget.person['reporter_email'] ?? 'N/A' 
                            : "•••••••••••• (Hidden)"
                      ),
                      if (widget.person['secondary_contact_name'] != null && widget.person['secondary_contact_name'].isNotEmpty) ...[
                        _buildDetailRow("Secondary Contact", widget.person['secondary_contact_name']),
                        _buildDetailRow(
                          "Secondary Phone", 
                           _isNumberRevealed 
                            ? widget.person['secondary_contact_phone'] ?? 'N/A' 
                            : "•••• •••• •••• (Hidden)"
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: _isCheckingSighting 
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: () => _showISawThemDialog(context),
                          icon: const Icon(Icons.campaign),
                          label: Text(
                            _isNumberRevealed ? "CONTACT FAMILY" : "I HAVE SEEN THIS PERSON",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isNumberRevealed ? const Color(0xFF8A7650) : const Color(0xFFC0392B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    if (status == null) return const SizedBox.shrink();
    
    Color color = Colors.red;
    String label = "MISSING";
    
    if (status == 'found') {
      color = Colors.green;
      label = "FOUND";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildQuickInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF8A7650), size: 24),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              value, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF8A7650),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8A7650), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    final displayValue = (value == null || (value is String && value.isEmpty)) ? "N/A" : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showISawThemDialog(BuildContext context) {
    if (_isNumberRevealed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("The relative's number is now revealed in the Contact Information section.")),
      );
      return;
    }

    final whereCtrl = TextEditingController();
    final whenCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    bool isWithThem = false;
    bool hasAgreed = false;
    bool isSubmitting = false;

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
                  Text(
                    "Report Sighting",
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF8A7650)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "A family is desperately waiting for news of their loved one. Please share what you know.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildModalTextField(label: "Where did you see them?", controller: whereCtrl, hint: "Specify location, landmark..."),
                  const SizedBox(height: 16),
                  _buildModalTextField(label: "When did you see them?", controller: whenCtrl, hint: "Date and approximate time..."),
                  const SizedBox(height: 16),
                  _buildModalTextField(label: "Any extra details?", controller: detailsCtrl, hint: "Clothing, direction, state of well-being...", maxLines: 3),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text("Are you with them right now?", style: TextStyle(fontWeight: FontWeight.bold)),
                    value: isWithThem,
                    onChanged: (val) => setStateModal(() => isWithThem = val),
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFFC0392B),
                  ),
                  
                  const Divider(height: 32),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: const Text(
                      "By submitting this, you confirm that what you've reported is true to the best of your knowledge.",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF856404)),
                    ),
                  ),
                  
                  CheckboxListTile(
                    title: const Text("I genuinely believe I have seen this person"),
                    value: hasAgreed,
                    onChanged: (val) => setStateModal(() => hasAgreed = val ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!hasAgreed || isSubmitting) ? null : () async {
                        setStateModal(() => isSubmitting = true);
                        try {
                          final sightingMsg = """
NEW SIGHTING REPORTED:
Location: ${whereCtrl.text}
Time: ${whenCtrl.text}
Details: ${detailsCtrl.text}
Finder is with them: ${isWithThem ? 'YES' : 'NO'}
""";
                          final reporterId = widget.person['reporter_id'];
                          if (reporterId != null) {
                            await Supabase.instance.client.from('notifications').insert({
                              'user_id': reporterId,
                              'title': 'Potential Sighting: ${widget.person['name']}',
                              'message': sightingMsg,
                              'type': 'sighting_report',
                              'metadata': {
                                'finder_id': Supabase.instance.client.auth.currentUser?.id,
                                'case_id': widget.person['id'],
                                'location': whereCtrl.text,
                                'time': whenCtrl.text,
                                'details': detailsCtrl.text,
                                'is_with_person': isWithThem,
                              }
                            });
                          }
                          
                          if (mounted) {
                            setState(() => _isNumberRevealed = true);
                            Navigator.pop(context);
                            _showSuccessDialog(context);
                          }
                        } catch (e) {
                          if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send report: $e")));
                          }
                        } finally {
                          if (mounted) setStateModal(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC0392B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Yes, I saw this person", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
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

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text("Thank You"),
          ],
        ),
        content: const Text(
          "Your report has been sent to the family. Their contact information is now revealed on the details page so you can call them directly.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A7650),
              foregroundColor: Colors.white,
            ),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildModalTextField({required String label, required TextEditingController controller, String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
