import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/image_watermark_util.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  Future<void> _downloadWatermarkedImage(String photoName) async {
    final imageUrl = 'https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/$photoName';
    
    try {
      // 1. Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception("Failed to fetch image");
      
      final Uint8List imageBytes = response.bodyBytes;
      
      // 2. Add watermark
      final locationDesc = (widget.person['location_description'] as List?)?.join(', ') ?? '';
      final detailedLocation = "${locationDesc.isNotEmpty ? '$locationDesc, ' : ''}${widget.person['lga_last_seen'] ?? ''}, ${widget.person['state_last_seen'] ?? ''}".trim();
      
      final watermarkedBytes = await ImageWatermarkUtil.addWatermark(
        imageBytes: imageBytes,
        name: widget.person['name'] ?? 'Unknown Name',
        date: _formatDate(widget.person['date_last_seen']),
        location: detailedLocation.length > 85 ? "${detailedLocation.substring(0, 82)}..." : detailedLocation,
        time: widget.person['time_last_seen'] ?? 'Unknown Time',
        contact: widget.person['reporter_phone'] ?? widget.person['reporter_email'] ?? 'N/A',
      );
      
      if (watermarkedBytes == null) throw Exception("Watermark failed");

      // 3. Save/Download
      if (kIsWeb) {
        final blob = html.Blob([watermarkedBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", "wherarethey_${widget.person['name'] ?? 'case'}.jpg")
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile Save logic (could use image_gallery_saver but we don't have it)
        // For now, let's at least share it or save to temp
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/shared_image.jpg');
        await file.writeAsBytes(watermarkedBytes);
        await Share.shareXFiles([XFile(file.path)], text: 'Check this case on WherAreThey');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: $e")));
      }
    }
  }

  void _showShareDialog(BuildContext context) {
    final caseId = widget.person['id'];
    final caseUrl = kIsWeb 
        ? html.window.location.href 
        : "https://wherarethey.vercel.app/case/$caseId"; // Fallback URL
    
    final photos = widget.person['photos'] as List? ?? [];
    List<String> selectedPhotos = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Share Case",
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF8A7650)),
                ),
                const SizedBox(height: 16),
                
                // Copy Link Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: Color(0xFF8A7650)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          caseUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: caseUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Link copied to clipboard")),
                          );
                        },
                        child: const Text("Copy"),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                Text(
                  "Download Images with Watermark",
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Images will include last seen location and contact info.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                
                if (photos.isEmpty)
                  const Text("No images available for this case.")
                else
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        final isSelected = selectedPhotos.contains(photo);
                        return GestureDetector(
                          onTap: () {
                            setStateModal(() {
                              if (isSelected) {
                                selectedPhotos.remove(photo);
                              } else {
                                selectedPhotos.add(photo);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected 
                                  ? Border.all(color: const Color(0xFF8A7650), width: 3)
                                  : Border.all(color: Colors.transparent),
                              image: DecorationImage(
                                image: NetworkImage('https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/$photo'),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: isSelected 
                                ? const Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Color(0xFF8A7650),
                                        child: Icon(Icons.check, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: selectedPhotos.isEmpty ? null : () async {
                      Navigator.pop(context); // Close dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Processing images, please wait...")),
                      );
                      for (final photo in selectedPhotos) {
                        await _downloadWatermarkedImage(photo);
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: Text(
                      selectedPhotos.isEmpty 
                        ? "Select Images to Download" 
                        : "Download ${selectedPhotos.length} Image(s)",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A7650),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
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
    final bool isAuthenticated = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: Stack(
        children: [
          CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: isDesktop ? 400 : 300,
            pinned: true,
            backgroundColor: const Color(0xFF8A7650),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                tooltip: "Share Case",
                onPressed: () => _showShareDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.flag_outlined, color: Colors.white),
                tooltip: "Report Case",
                onPressed: () {
                  if (Supabase.instance.client.auth.currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please sign in to report this case")),
                    );
                    context.push('/auth');
                    return;
                  }
                  _showReportCaseDialog(context);
                },
              ),
              const SizedBox(width: 8),
            ],
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
                  if (photos.isNotEmpty) ...[
                    // Blurred background (stretched to fill)
                    Image.network(
                      'https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/${photos[0]}',
                      fit: BoxFit.cover,
                    ),
                    ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                        child: Container(
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ),
                    ),
                    // Foreground image (perfect size/aspect ratio)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: Supabase.instance.client.auth.currentUser == null ? 15.0 : 0.0,
                        sigmaY: Supabase.instance.client.auth.currentUser == null ? 15.0 : 0.0,
                      ),
                      child: Center(
                        child: Image.network(
                          'https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/${photos[0]}',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ] else
                    Container(
                      color: const Color(0xFF8A7650),
                      child: Center(
                        child: Opacity(
                          opacity: 0.3,
                          child: Image.asset('assets/user.png', height: 150),
                        ),
                      ),
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
                                  colorFilter: Supabase.instance.client.auth.currentUser == null
                                      ? ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken) // Fallback or extra effect
                                      : null,
                                ),
                              ),
                              child: Supabase.instance.client.auth.currentUser == null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        child: Container(color: Colors.transparent),
                                      ),
                                    )
                                  : null,
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
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        if (Supabase.instance.client.auth.currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please sign in to report a case")));
                          context.push('/auth');
                          return;
                        }
                        _showReportCaseDialog(context);
                      },
                      icon: const Icon(Icons.report_problem_outlined, color: Colors.grey, size: 16),
                      label: const Text("Is there something wrong with this case? Report it here", 
                        style: TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.underline)),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      if (!isAuthenticated)
        _buildAuthOverlay(context),
      ],
     ),
    );
  }

  Widget _buildAuthOverlay(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: const Color(0xFFF9F7F2).withOpacity(0.6),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A7650).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_person_outlined, size: 48, color: Color(0xFF8A7650)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Information Protected",
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "To protect the privacy of the missing person and their family, full case details are only visible to authenticated users.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push('/auth'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A7650),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Sign In / Register", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text("Back to Home", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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

  void _showReportCaseDialog(BuildContext context) {
    final reasonCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
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
                    "Report Case",
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF8A7650)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Is something wrong with this case? Let us know why it should be reviewed.",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Main Reason", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "Inappropriate Content", child: Text("Inappropriate Content")),
                      DropdownMenuItem(value: "Incorrect Information", child: Text("Incorrect Information")),
                      DropdownMenuItem(value: "Found Person", child: Text("Person has been found")),
                      DropdownMenuItem(value: "Spam", child: Text("Spam / Fake Case")),
                      DropdownMenuItem(value: "Duplicate", child: Text("Duplicate Case")),
                      DropdownMenuItem(value: "Other", child: Text("Other")),
                    ],
                    onChanged: (val) => reasonCtrl.text = val ?? "",
                  ),
                  const SizedBox(height: 16),
                  _buildModalTextField(
                    label: "Additional Details (Optional)", 
                    controller: detailsCtrl, 
                    hint: "Provide more context...", 
                    maxLines: 4
                  ),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (reasonCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a reason")));
                          return;
                        }
                        
                        setStateModal(() => isSubmitting = true);
                        try {
                          await Supabase.instance.client.from('case_reports').insert({
                            'case_id': widget.person['id'],
                            'reporter_id': Supabase.instance.client.auth.currentUser?.id,
                            'reason': reasonCtrl.text,
                            'details': detailsCtrl.text,
                          });
                          
                          // Also update the case's last_reported_at to surface it in moderation
                          await Supabase.instance.client
                              .from('cases')
                              .update({'last_reported_at': DateTime.now().toIso8601String()})
                              .eq('id', widget.person['id']);

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Thank you. Our moderators will review this case shortly.")),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to submit report: $e")));
                          }
                        } finally {
                          if (mounted) setStateModal(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A7650),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Submit Report", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
