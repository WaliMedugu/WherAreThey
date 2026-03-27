import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../utils/seo_util.dart';
import '../data/nigeria_data.dart';
import 'case_details_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String initialQuery;

  const SearchResultsScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _searchResults = [];
  String _currentQuery = '';

  bool _showDetailedSearch = false;
  String? _selectedGender;
  String? _selectedEyeColor;
  String? _selectedSkinTone;
  String? _selectedBuild;
  String? _selectedHeight;
  final TextEditingController _nicknameController = TextEditingController();
  
  // Expanded filters
  String? _dobDay;
  String? _dobMonth;
  String? _dobYear;
  String? _selectedState;
  String? _selectedLga;
  final TextEditingController _marksController = TextEditingController();
  final TextEditingController _medicalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _currentQuery = widget.initialQuery;
    SeoUtil.updateMeta(
      title: 'Search Missing Persons - WherAreThey',
      description: 'Search results for missing persons in Nigeria.',
    );
    if (_currentQuery.isNotEmpty) {
      _performSearch();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nicknameController.dispose();
    _marksController.dispose();
    _medicalController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    final nickname = _nicknameController.text.trim();
    final marks = _marksController.text.trim();
    final medical = _medicalController.text.trim();
    
    setState(() {
      _isLoading = true;
      _currentQuery = query.isEmpty ? (nickname.isNotEmpty ? "Nickname: $nickname" : "Filtered Search") : query;
    });

    try {
      var request = Supabase.instance.client
          .from('cases')
          .select()
          .eq('status', 'active');

      if (query.isNotEmpty) {
        request = request.ilike('name', '%$query%');
      }

      if (nickname.isNotEmpty) {
        request = request.contains('aliases', [nickname]);
      }

      if (marks.isNotEmpty) {
        request = request.contains('distinguishing_marks', [marks]);
      }

      if (medical.isNotEmpty) {
        request = request.contains('medical_conditions', [medical]);
      }

      if (_selectedGender != null) {
        request = request.eq('gender', _selectedGender!);
      }

      if (_selectedEyeColor != null) {
        request = request.eq('eye_color', _selectedEyeColor!);
      }

      if (_selectedSkinTone != null) {
        request = request.eq('skin_tone', _selectedSkinTone!);
      }

      if (_selectedBuild != null) {
        request = request.eq('build', _selectedBuild!);
      }

      if (_selectedHeight != null) {
        request = request.eq('height', _selectedHeight!);
      }

      if (_selectedState != null) {
        request = request.eq('state_last_seen', _selectedState!);
      }

      if (_selectedLga != null) {
        request = request.eq('lga_last_seen', _selectedLga!);
      }

      if (_dobYear != null && _dobMonth != null && _dobDay != null) {
        final dob = '$_dobYear-${_dobMonth!.padLeft(2, '0')}-${_dobDay!.padLeft(2, '0')}';
        request = request.eq('dob', dob);
      } else if (_dobYear != null) {
        // Approximate year match if full DOB not provided? 
        // Supabase/Postgres doesn't have a direct "year" match on DATE without raw SQL or ranges
        // For simplicity, let's stick to full DOB if provided.
      }

      final response = await request.limit(50);
      
      if (mounted) {
        setState(() {
          _searchResults = (response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Search failed: $e");
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedGender = null;
      _selectedEyeColor = null;
      _selectedSkinTone = null;
      _selectedBuild = null;
      _selectedHeight = null;
      _nicknameController.clear();
      _marksController.clear();
      _medicalController.clear();
      _dobDay = null;
      _dobMonth = null;
      _dobYear = null;
      _selectedState = null;
      _selectedLga = null;
      if (_searchController.text.isEmpty && _currentQuery.isNotEmpty) {
        _searchResults = [];
        _currentQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Search Database",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF8A7650),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
        children: [
          // Search Header Area
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Container(
                          width: isDesktop ? 600 : double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Color(0xFF8A7650)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onSubmitted: (_) => _performSearch(),
                                  autofocus: widget.initialQuery.isEmpty,
                                  decoration: const InputDecoration(
                                    hintText: "Enter name, age, or location...",
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _performSearch,
                                icon: const Icon(Icons.arrow_forward, color: Color(0xFF8A7650)),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            if (Supabase.instance.client.auth.currentUser == null) {
                              context.push('/auth');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please sign in to use advanced search filters")),
                              );
                            } else {
                              setState(() => _showDetailedSearch = !_showDetailedSearch);
                            }
                          },
                          icon: Icon(_showDetailedSearch ? Icons.expand_less : Icons.tune),
                          label: const Text("Describe who"),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8A7650),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Detailed Search Section
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: _showDetailedSearch 
                      ? Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Physical & Location Details", 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700)
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _clearFilters,
                                    child: const Text("Clear Filters", style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildFilterDropdown(
                                    label: "Gender", 
                                    value: _selectedGender, 
                                    items: ['Male', 'Female', 'Unknown'],
                                    onChanged: (val) => setState(() => _selectedGender = val),
                                    width: 150,
                                  ),
                                  _buildFilterDropdown(
                                    label: "Eye Color", 
                                    value: _selectedEyeColor, 
                                    items: ['Black', 'Dark Brown', 'Light Brown', 'Green', 'Blue', 'Other', 'Unknown'],
                                    onChanged: (val) => setState(() => _selectedEyeColor = val),
                                    width: 150,
                                  ),
                                  _buildFilterDropdown(
                                    label: "Skin Tone", 
                                    value: _selectedSkinTone, 
                                    items: ['Fair', 'Light Brown', 'Medium Brown', 'Dark Brown', 'Very Dark', 'Albinism'],
                                    onChanged: (val) => setState(() => _selectedSkinTone = val),
                                    width: 150,
                                  ),
                                  _buildFilterDropdown(
                                    label: "Build", 
                                    value: _selectedBuild, 
                                    items: ['Slim', 'Average', 'Athletic', 'Heavy'],
                                    onChanged: (val) => setState(() => _selectedBuild = val),
                                    width: 150,
                                  ),
                                  _buildFilterDropdown(
                                    label: "Height Range", 
                                    value: _selectedHeight, 
                                    items: [
                                      'Under 2ft', '2ft 0in - 2ft 6in', '2ft 6in - 3ft 0in', 
                                      '3ft 0in - 3ft 6in', '3ft 6in - 4ft 0in', '4ft 0in - 4ft 6in', 
                                      '4ft 6in - 5ft 0in', '5ft 0in - 5ft 6in', '5ft 6in - 6ft 0in', 
                                      '6ft 0in - 6ft 6in', '6ft 0in - 7ft 0in', 'Over 7ft'
                                    ],
                                    onChanged: (val) => setState(() => _selectedHeight = val),
                                    width: 200,
                                  ),
                                  _buildFilterDropdown(
                                    label: "State Last Seen", 
                                    value: _selectedState, 
                                    items: NigeriaData.states,
                                    onChanged: (val) => setState(() {
                                      _selectedState = val;
                                      _selectedLga = null;
                                    }),
                                    width: 180,
                                  ),
                                  _buildFilterDropdown(
                                    label: "LGA Last Seen", 
                                    value: _selectedLga, 
                                    items: _selectedState != null ? NigeriaData.statesAndLgas[_selectedState!]! : [],
                                    onChanged: (val) => setState(() => _selectedLga = val),
                                    width: 180,
                                  ),
                                  _buildDateFilter(),
                                  _buildTextField(
                                    label: "Nickname/Alias",
                                    controller: _nicknameController,
                                    width: 200,
                                  ),
                                  _buildTextField(
                                    label: "Distinguishing Marks",
                                    controller: _marksController,
                                    width: 200,
                                  ),
                                  _buildTextField(
                                    label: "Medical Conditions",
                                    controller: _medicalController,
                                    width: 200,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _performSearch,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8A7650),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text("Apply Detailed Search"),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          
          // Results Info
          if (_currentQuery.isNotEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Results for \"$_currentQuery\"",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8A7650).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_searchResults.length} found",
                        style: const TextStyle(
                          color: Color(0xFF8A7650),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search Results Grid
          _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty 
                ? _buildEmptyState()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktop ? 4 : 2,
                            crossAxisSpacing: 24,
                            mainAxisSpacing: 24,
                            childAspectRatio: 0.65,
                          ),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final person = _searchResults[index];
                            return _buildCaseCard(person);
                          },
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    ),
  );
}

  Widget _buildEmptyState() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.blueGrey.shade100),
            const SizedBox(height: 16),
            Text(
              "Start typing to search our database",
              style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 80, color: Colors.blueGrey.shade100),
          const SizedBox(height: 16),
          Text(
            "No matching cases found for \"$_currentQuery\"",
            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text("Try checking the name or searching by location"),
        ],
      ),
    );
  }

  Widget _buildCaseCard(dynamic person) {
    return InkWell(
      onTap: () {
        context.push('/case/${person['id']}', extra: person);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: Colors.blueGrey.shade50,
                width: double.infinity,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: Supabase.instance.client.auth.currentUser == null ? 10.0 : 0.0,
                    sigmaY: Supabase.instance.client.auth.currentUser == null ? 10.0 : 0.0,
                  ),
                  child: (person['photos'] != null && (person['photos'] as List).isNotEmpty)
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              'https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/${person['photos'][0]}',
                              fit: BoxFit.cover,
                            ),
                            BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(color: Colors.black.withOpacity(0.05)),
                            ),
                            Image.network(
                              'https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/${person['photos'][0]}',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => 
                                Image.asset('assets/user.png', fit: BoxFit.cover),
                            ),
                          ],
                        )
                      : Image.asset('assets/user.png', fit: BoxFit.cover),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person['name'] ?? 'Unknown Name',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last seen: ${person['lga_last_seen'] ?? ''} ${person['state_last_seen'] ?? ''}".trim(),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Missing",
                          style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF8A7650)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final days = List.generate(31, (i) => (i + 1).toString());
    final months = List.generate(12, (i) => (i + 1).toString());
    final currentYear = DateTime.now().year;
    final years = List.generate(120, (i) => (currentYear - i).toString());

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Date of Birth", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _dobDay,
                  hint: const Text("Day"),
                  items: days.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _dobDay = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _dobMonth,
                  hint: const Text("Month"),
                  items: months.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _dobMonth = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _dobYear,
                  hint: const Text("Year"),
                  items: years.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _dobYear = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
