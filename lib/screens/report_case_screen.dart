import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:search_choices/search_choices.dart';
import '../services/storage_service.dart';
import '../widgets/chip_input_field.dart';
import '../data/nigeria_data.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_screen.dart';

class ReportCaseScreen extends StatefulWidget {
  final String? caseId;
  const ReportCaseScreen({super.key, this.caseId});

  @override
  State<ReportCaseScreen> createState() => _ReportCaseScreenState();
}

class _ReportCaseScreenState extends State<ReportCaseScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6; // 0: Identity, 1: Physical, 2: Disappearance, 3: Photos, 4: Contact, 5: Review
  
  final _formKeys = List.generate(6, (_) => GlobalKey<FormState>());

  // Step 1: Identity
  bool _isUnconscious = false;
  final _fullNameCtrl = TextEditingController();
  bool _fullNameUnknown = false;
  List<String> _aliasesList = [];
  String? _dobDay;
  String? _dobMonth;
  String? _dobYear;
  bool _dobExactUnknown = false;
  String? _primaryAgeRange;
  String? _secondaryAgeRange;
  String? _gender;
  final _nationalityCtrl = TextEditingController(text: 'Nigerian');
  String? _stateOrigin;
  final _tribeCtrl = TextEditingController();
  List<String> _languagesList = [];

  // Step 2: Physical
  String? _heightRange;
  bool _heightUnknown = false;
  String? _build;
  String? _skinTone;
  String? _eyeColor;
  List<String> _hairList = [];
  List<String> _marksList = [];
  List<String> _clothingList = [];

  // Step 3: Disappearance
  String? _seenDay;
  String? _seenMonth;
  String? _seenYear;
  bool _dateApproximate = false;
  final _timeSeenCtrl = TextEditingController();
  bool _timeUnknown = false;
  String? _stateSeen;
  String? _lgaSeen;
  List<String> _locationDescList = [];
  List<String> _circumstancesList = [];
  final _occupationCtrl = TextEditingController();
  List<String> _medicalList = [];

  // Step 4: Photos
  List<XFile> _selectedImages = [];
  List<String> _existingPhotos = [];
  final _policeRefCtrl = TextEditingController();

  // Step 5: Contact
  final _registrantNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _secondaryNameCtrl = TextEditingController();
  final _secondaryPhoneCtrl = TextEditingController();
  String? _relationship;
  String? _reportedByType;
  bool _consentGiven = false;

  bool _isUploading = false;
  bool _isSubmitted = false;
  String? _submittedCaseRef;

  final _supabase = Supabase.instance.client;
  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _loadUserContactData();
    if (widget.caseId != null) {
      _loadCaseData();
    } else {
      _loadDraft();
    }
  }

  Future<void> _loadCaseData() async {
    setState(() => _isUploading = true);
    try {
      final data = await _supabase
          .from('cases')
          .select()
          .eq('id', widget.caseId as Object)
          .single();

      if (mounted) {
        setState(() {
          _isUnconscious = data['is_unconscious'] ?? false;
          _fullNameCtrl.text = data['name'] == 'Unknown' ? '' : (data['name'] ?? '');
          _fullNameUnknown = data['full_name_unknown'] ?? false;
          _aliasesList = List<String>.from(data['aliases'] ?? []);
          _dobExactUnknown = data['dob_unknown'] ?? false;
          _existingPhotos = List<String>.from(data['photos'] ?? []);
          
          if (data['dob'] != null) {
            final dobDate = DateTime.parse(data['dob']);
            _dobDay = dobDate.day.toString();
            _dobMonth = dobDate.month.toString();
            _dobYear = dobDate.year.toString();
          }
          
          _primaryAgeRange = data['age_primary'];
          _secondaryAgeRange = data['age_secondary'];
          _gender = data['gender'];
          _nationalityCtrl.text = data['nationality'] ?? 'Nigerian';
          _stateOrigin = data['state_of_origin'];
          _tribeCtrl.text = data['tribe'] ?? '';
          _languagesList = List<String>.from(data['languages_spoken'] ?? []);
          
          _heightRange = data['height'];
          _heightUnknown = data['height_unknown'] ?? false;
          _build = data['build'];
          _skinTone = data['skin_tone'];
          _eyeColor = data['eye_color'];
          _hairList = List<String>.from(data['hair_description'] ?? []);
          _marksList = List<String>.from(data['distinguishing_marks'] ?? []);
          _clothingList = List<String>.from(data['last_clothing'] ?? []);
          
          if (data['date_last_seen'] != null) {
            final seenDate = DateTime.parse(data['date_last_seen']);
            _seenDay = seenDate.day.toString();
            _seenMonth = seenDate.month.toString();
            _seenYear = seenDate.year.toString();
          }
          
          _dateApproximate = data['date_is_approximate'] ?? false;
          _timeSeenCtrl.text = data['time_last_seen'] ?? '';
          _timeUnknown = data['time_last_seen'] == 'Unknown';
          _stateSeen = data['state_last_seen'];
          _lgaSeen = data['lga_last_seen'];
          _locationDescList = List<String>.from(data['location_description'] ?? []);
          
          final circs = data['circumstances'] as String?;
          _circumstancesList = circs != null ? circs.split('; ') : [];
          
          _occupationCtrl.text = data['occupation_school'] ?? '';
          _medicalList = List<String>.from(data['medical_conditions'] ?? []);
          _policeRefCtrl.text = data['police_reference'] ?? '';
          
          _registrantNameCtrl.text = data['reporter_full_name'] ?? '';
          _contactPhoneCtrl.text = data['reporter_phone'] ?? '';
          _contactEmailCtrl.text = data['reporter_email'] ?? '';
          _relationship = data['reporter_relationship'];
          _reportedByType = data['reported_by_type'];
          _secondaryNameCtrl.text = data['secondary_contact_name'] ?? '';
          _secondaryPhoneCtrl.text = data['secondary_contact_phone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading case data: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _loadUserContactData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      if (_registrantNameCtrl.text.isEmpty) _registrantNameCtrl.text = user.userMetadata?['full_name'] ?? '';
      if (_contactEmailCtrl.text.isEmpty) _contactEmailCtrl.text = user.email ?? '';
      if (_contactPhoneCtrl.text.isEmpty) _contactPhoneCtrl.text = user.phone ?? '';
    }
  }

  Future<void> _saveDraft() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final draftData = {
      'isUnconscious': _isUnconscious,
      'fullName': _fullNameCtrl.text,
      'fullNameUnknown': _fullNameUnknown,
      'aliasesList': _aliasesList,
      'dobDay': _dobDay,
      'dobMonth': _dobMonth,
      'dobYear': _dobYear,
      'dobExactUnknown': _dobExactUnknown,
      'primaryAgeRange': _primaryAgeRange,
      'secondaryAgeRange': _secondaryAgeRange,
      'gender': _gender,
      'nationality': _nationalityCtrl.text,
      'stateOrigin': _stateOrigin,
      'tribe': _tribeCtrl.text,
      'languagesList': _languagesList,
      'height': _heightRange,
      'heightUnknown': _heightUnknown,
      'build': _build,
      'skinTone': _skinTone,
      'eyeColor': _eyeColor,
      'hairList': _hairList,
      'marksList': _marksList,
      'clothingList': _clothingList,
      'seenDay': _seenDay,
      'seenMonth': _seenMonth,
      'seenYear': _seenYear,
      'dateApproximate': _dateApproximate,
      'timeSeen': _timeSeenCtrl.text,
      'timeUnknown': _timeUnknown,
      'stateSeen': _stateSeen,
      'lgaSeen': _lgaSeen,
      'locationDescList': _locationDescList,
      'circumstancesList': _circumstancesList,
      'occupation': _occupationCtrl.text,
      'medicalList': _medicalList,
      'policeRef': _policeRefCtrl.text,
      'registrantName': _registrantNameCtrl.text,
      'contactPhone': _contactPhoneCtrl.text,
      'contactEmail': _contactEmailCtrl.text,
      'secondaryName': _secondaryNameCtrl.text,
      'secondaryPhone': _secondaryPhoneCtrl.text,
      'relationship': _relationship,
      'reportedByType': _reportedByType,
    };

    try {
      await _supabase.from('case_drafts').upsert({
        'user_id': user.id,
        'step_index': _currentStep,
        'form_data': draftData,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Future<void> _loadDraft() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('case_drafts')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        final draft = data['form_data'] as Map<String, dynamic>;
        setState(() {
          _currentStep = data['step_index'] ?? 0;
          _isUnconscious = draft['isUnconscious'] ?? false;
          _fullNameCtrl.text = draft['fullName'] ?? '';
          _fullNameUnknown = draft['fullNameUnknown'] ?? false;
          _aliasesList = List<String>.from(draft['aliasesList'] ?? []);
          _dobDay = draft['dobDay'];
          _dobMonth = draft['dobMonth'];
          _dobYear = draft['dobYear'];
          _dobExactUnknown = draft['dobExactUnknown'] ?? false;
          _primaryAgeRange = draft['primaryAgeRange'];
          _secondaryAgeRange = draft['secondaryAgeRange'];
          _gender = draft['gender'];
          _nationalityCtrl.text = draft['nationality'] ?? 'Nigerian';
          _stateOrigin = draft['stateOrigin'];
          _tribeCtrl.text = draft['tribe'] ?? '';
          _languagesList = List<String>.from(draft['languagesList'] ?? []);
          _heightRange = draft['height'];
          _heightUnknown = draft['heightUnknown'] ?? false;
          _build = draft['build'];
          _skinTone = draft['skinTone'];
          _eyeColor = draft['eyeColor'];
          _hairList = List<String>.from(draft['hairList'] ?? []);
          _marksList = List<String>.from(draft['marksList'] ?? []);
          _clothingList = List<String>.from(draft['clothingList'] ?? []);
          _seenDay = draft['seenDay'];
          _seenMonth = draft['seenMonth'];
          _seenYear = draft['seenYear'];
          _dateApproximate = draft['dateApproximate'] ?? false;
          _timeSeenCtrl.text = draft['timeSeen'] ?? '';
          _timeUnknown = draft['timeUnknown'] ?? false;
          _stateSeen = draft['stateSeen'];
          _lgaSeen = draft['lgaSeen'];
          _locationDescList = List<String>.from(draft['locationDescList'] ?? []);
          _circumstancesList = List<String>.from(draft['circumstancesList'] ?? []);
          _occupationCtrl.text = draft['occupation'] ?? '';
          _medicalList = List<String>.from(draft['medicalList'] ?? []);
          _policeRefCtrl.text = draft['policeRef'] ?? '';
          _registrantNameCtrl.text = draft['registrantName'] ?? '';
          _contactPhoneCtrl.text = draft['contactPhone'] ?? '';
          _contactEmailCtrl.text = draft['contactEmail'] ?? '';
          _secondaryNameCtrl.text = draft['secondaryName'] ?? '';
          _secondaryPhoneCtrl.text = draft['secondaryPhone'] ?? '';
          _relationship = draft['relationship'];
          _reportedByType = draft['reportedByType'];
        });
        
        // Jump to the saved page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentStep);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft loaded. Resuming your report.'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameCtrl.dispose();
    _nationalityCtrl.dispose();
    _tribeCtrl.dispose();
    _timeSeenCtrl.dispose();
    _occupationCtrl.dispose();
    _policeRefCtrl.dispose();
    _registrantNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    _secondaryNameCtrl.dispose();
    _secondaryPhoneCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKeys[_currentStep].currentState?.validate() ?? false) {
      if (_currentStep < _totalSteps - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        setState(() => _currentStep++);
        _saveDraft();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
      _saveDraft();
    }
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 photos allowed')));
      return;
    }
    
    try {
      final picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 80, 
        maxWidth: 2000, 
        maxHeight: 2000
      );
      
      if (images.isNotEmpty && mounted) {
        setState(() {
          for (var img in images) {
            if (_selectedImages.length < 3) {
              _selectedImages.add(img);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open gallery. Please ensure permissions are granted.')));
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to submit a report.')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      bool isMinor = false;
      String? dob;
      String? ageRange;
      if (!_isUnconscious && !_dobExactUnknown && _dobDay != null && _dobMonth != null && _dobYear != null) {
        dob = '$_dobYear-${_dobMonth!.padLeft(2, '0')}-${_dobDay!.padLeft(2, '0')}';
        final dobDate = DateTime.parse(dob);
        isMinor = DateTime.now().difference(dobDate).inDays < 365 * 18;
      } else if (_primaryAgeRange != null || _secondaryAgeRange != null) {
        ageRange = 'Primary: ${_primaryAgeRange ?? "Unknown"}, Secondary: ${_secondaryAgeRange ?? "Unknown"}';
        isMinor = ageRange.contains('Infant') || 
                  ageRange.contains('Baby') || 
                  ageRange.contains('Toddler') || 
                  ageRange.contains('Child') || 
                  ageRange.contains('Teenager');
      }

      final caseData = {
        'reporter_id': user.id,
        'status': 'pending',
        'is_unconscious': _isUnconscious,
        'full_name_unknown': _fullNameUnknown,
        'name': (_fullNameUnknown || (_isUnconscious && _fullNameCtrl.text.trim().isEmpty)) ? 'Unknown' : _fullNameCtrl.text.trim(),
        'aliases': _isUnconscious ? null : _aliasesList,
        'dob': dob,
        'age_primary': _primaryAgeRange,
        'age_secondary': _secondaryAgeRange,
        'gender': _gender ?? 'Unknown',
        'dob_unknown': _dobExactUnknown,
        'nationality': _isUnconscious ? 'Unknown' : _nationalityCtrl.text.trim(),
        'state_of_origin': _isUnconscious ? null : _stateOrigin,
        'tribe': _isUnconscious ? null : _tribeCtrl.text.trim(),
        'languages_spoken': _isUnconscious ? null : _languagesList,
        'height_unknown': _heightUnknown,
        'height': _heightUnknown ? null : _heightRange,
        'build': _build,
        'skin_tone': _skinTone,
        'eye_color': _eyeColor,
        'hair_description': _hairList,
        'distinguishing_marks': _marksList,
        'last_clothing': _clothingList,
        'date_last_seen': (_seenDay != null && _seenMonth != null && _seenYear != null) 
          ? '$_seenYear-${_seenMonth!.padLeft(2, '0')}-${_seenDay!.padLeft(2, '0')}' 
          : DateTime.now().toIso8601String().split('T')[0],
        'date_is_approximate': _dateApproximate,
        'time_last_seen': _timeUnknown ? 'Unknown' : _timeSeenCtrl.text.trim(),
        'state_last_seen': _stateSeen ?? 'Unknown',
        'lga_last_seen': _lgaSeen,
        'location_description': _locationDescList,
        'circumstances': _circumstancesList.join('; '),
        'occupation_school': _isUnconscious ? null : _occupationCtrl.text.trim(),
        'medical_conditions': _medicalList,
        'police_reference': _policeRefCtrl.text.trim(),
        'reporter_full_name': _registrantNameCtrl.text.trim(),
        'reporter_phone': _contactPhoneCtrl.text.trim(),
        'reporter_email': _contactEmailCtrl.text.trim(),
        'reporter_relationship': _relationship ?? 'Authority',
        'reported_by_type': _reportedByType ?? 'Third Party',
        'secondary_contact_name': _secondaryNameCtrl.text.trim(),
        'secondary_contact_phone': _secondaryPhoneCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      String caseId;
      if (widget.caseId != null) {
        await _supabase.from('cases').update(caseData).eq('id', widget.caseId as Object);
        caseId = widget.caseId!;
      } else {
        final caseRes = await _supabase.from('cases').insert(caseData).select('id').single();
        caseId = caseRes['id'] as String;
      }

      // Photo upload logic
      List<String> uploadedPaths = [];
      // If editing, we might want to keep existing photos or add new ones. 
      // For now, if new images are selected, we upload them and append.
      if (_selectedImages.isNotEmpty) {
        for (var image in _selectedImages) {
          final photoPaths = await _storageService.uploadCasePhoto(image, caseId);
          if (photoPaths != null) {
            uploadedPaths.add(photoPaths['full']!);
          }
        }

        if (uploadedPaths.isNotEmpty || _existingPhotos.length != (widget.caseId != null ? 3 : 0)) {
          await _supabase.from('cases').update({
            'photos': [..._existingPhotos, ...uploadedPaths].take(3).toList(),
          }).eq('id', caseId);
        }
      } else if (widget.caseId != null) {
        // Even if no new images, we might have removed existing ones
        await _supabase.from('cases').update({
          'photos': _existingPhotos,
        }).eq('id', caseId);
      }
      
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isSubmitted = true;
          _submittedCaseRef = 'Case Submitted'; 
        });
        await _supabase.from('case_drafts').delete().eq('user_id', user.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red));
        setState(() => _isUploading = false);
      }
    }
  }

  // Helper method for Date Dropdowns
  Widget _buildDateDropdowns({
    required String label,
    required String? day,
    required String? month,
    required String? year,
    required void Function(String?) onDayChanged,
    required void Function(String?) onMonthChanged,
    required void Function(String?) onYearChanged,
  }) {
    final days = List.generate(31, (i) => (i + 1).toString());
    final months = List.generate(12, (i) => (i + 1).toString());
    final currentYear = DateTime.now().year;
    final years = List.generate(120, (i) => (currentYear - i).toString());

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Day'),
                value: day,
                items: days.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onDayChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Month'),
                value: month,
                items: months.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onMonthChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Year'),
                value: year,
                items: years.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onYearChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepWrapper(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: child,
        ),
      ),
    );
  }

  Widget _buildIdentityStep() {
    return _buildStepWrapper(
      Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 1 — Identity', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Who is this person?'),
            const SizedBox(height: 24),

            SwitchListTile(
              title: const Text('Is Unconscious / Inaudible?'),
              subtitle: const Text('Check this if you found them and they cannot speak.'),
              value: _isUnconscious,
              onChanged: (val) {
                setState(() {
                  _isUnconscious = val;
                  if (val) {
                    _fullNameUnknown = false;
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            
            if (!_isUnconscious)
              SwitchListTile(
                title: const Text('Full name unknown'),
                value: _fullNameUnknown,
                onChanged: (val) {
                  setState(() => _fullNameUnknown = val);
                  if (val) _fullNameCtrl.clear();
                },
                contentPadding: EdgeInsets.zero,
              ),
            if (!_fullNameUnknown || _isUnconscious)
              TextFormField(
                controller: _fullNameCtrl,
                decoration: InputDecoration(
                  labelText: _isUnconscious ? 'Name if known (leave blank if unknown)' : 'Full name', 
                  border: const OutlineInputBorder()
                ),
                validator: (val) {
                  if (_isUnconscious) return null;
                  return (val == null || val.isEmpty) ? 'Required (or check unknown)' : null;
                },
              ),
            const SizedBox(height: 16),
            
            if (!_isUnconscious) ...[
              ChipInputField(
                labelText: 'Known nicknames or aliases',
                hintText: 'Type and separate with comma...',
                initialChips: _aliasesList,
                onChanged: (val) => setState(() => _aliasesList = val),
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text("I don't know the exact date of birth"),
                value: _dobExactUnknown,
                onChanged: (val) {
                  setState(() {
                    _dobExactUnknown = val;
                    if (val) {
                      _dobDay = null;
                      _dobMonth = null;
                      _dobYear = null;
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (!_dobExactUnknown)
               _buildDateDropdowns(
                  label: 'Exact Date of Birth',
                  day: _dobDay,
                  month: _dobMonth,
                  year: _dobYear,
                  onDayChanged: (val) => setState(() => _dobDay = val),
                  onMonthChanged: (val) => setState(() => _dobMonth = val),
                  onYearChanged: (val) => setState(() => _dobYear = val),
               ),
            ],
            
            if (_dobExactUnknown || _isUnconscious) ...[
              const SizedBox(height: 8),
              const Text('Please select the two most likely age ranges:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Primary Age Estimate', border: OutlineInputBorder()),
                isExpanded: true,
                value: _primaryAgeRange,
                items: const [
                  DropdownMenuItem(value: 'Infant (0 - 11 months)', child: Text('Infant (0 - 11 months)')),
                  DropdownMenuItem(value: 'Baby (1 - 2 years)', child: Text('Baby (1 - 2 years)')),
                  DropdownMenuItem(value: 'Toddler (2 - 4 years)', child: Text('Toddler (2 - 4 years)')),
                  DropdownMenuItem(value: 'Child (5 - 12 years)', child: Text('Child (5 - 12 years)')),
                  DropdownMenuItem(value: 'Teenager (13 - 17 years)', child: Text('Teenager (13 - 17 years)')),
                  DropdownMenuItem(value: 'Young Adult (18 - 35 years)', child: Text('Young Adult (18 - 35 years)')),
                  DropdownMenuItem(value: 'Middle Aged (36 - 55 years)', child: Text('Middle Aged (36 - 55 years)')),
                  DropdownMenuItem(value: 'Older Adult (56 - 70 years)', child: Text('Older Adult (56 - 70 years)')),
                  DropdownMenuItem(value: 'Elderly (71 years +)', child: Text('Elderly (71 years +)')),
                ],
                onChanged: (val) => setState(() => _primaryAgeRange = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Secondary Age Estimate', border: OutlineInputBorder()),
                isExpanded: true,
                value: _secondaryAgeRange,
                items: const [
                  DropdownMenuItem(value: 'Infant (0 - 11 months)', child: Text('Infant (0 - 11 months)')),
                  DropdownMenuItem(value: 'Baby (1 - 2 years)', child: Text('Baby (1 - 2 years)')),
                  DropdownMenuItem(value: 'Toddler (2 - 4 years)', child: Text('Toddler (2 - 4 years)')),
                  DropdownMenuItem(value: 'Child (5 - 12 years)', child: Text('Child (5 - 12 years)')),
                  DropdownMenuItem(value: 'Teenager (13 - 17 years)', child: Text('Teenager (13 - 17 years)')),
                  DropdownMenuItem(value: 'Young Adult (18 - 35 years)', child: Text('Young Adult (18 - 35 years)')),
                  DropdownMenuItem(value: 'Middle Aged (36 - 55 years)', child: Text('Middle Aged (36 - 55 years)')),
                  DropdownMenuItem(value: 'Older Adult (56 - 70 years)', child: Text('Older Adult (56 - 70 years)')),
                  DropdownMenuItem(value: 'Elderly (71 years +)', child: Text('Elderly (71 years +)')),
                ],
                onChanged: (val) => setState(() => _secondaryAgeRange = val),
              ),
            ],
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              value: _gender,
              items: ['Male', 'Female', 'Unknown'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _gender = val),
              validator: (val) => val == null ? 'Gender is required' : null,
            ),
            const SizedBox(height: 16),

            if (!_isUnconscious) ...[
              TextFormField(
                controller: _nationalityCtrl,
                decoration: const InputDecoration(labelText: 'Nationality', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              
              SearchChoices.single(
                items: NigeriaData.states.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                value: _stateOrigin,
                hint: const Text('State of Origin'),
                searchHint: const Text('Type to search state...'),
                onChanged: (val) => setState(() => _stateOrigin = val),
                isExpanded: true,
                displayClearIcon: false,
                underline: Container(height: 1, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _tribeCtrl,
                decoration: const InputDecoration(labelText: 'Tribe / Ethnicity (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              
               ChipInputField(
                labelText: 'Languages spoken',
                hintText: 'e.g. English, Hausa, Pidgin...',
                initialChips: _languagesList,
                onChanged: (val) => setState(() => _languagesList = val),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalStep() {
    return _buildStepWrapper(
      Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 2 — Physical Description', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('What do they look like?'),
            const SizedBox(height: 24),
            
            SwitchListTile(
              title: const Text('Height Unknown'),
              value: _heightUnknown,
              onChanged: (val) {
                setState(() => _heightUnknown = val);
                if (val) _heightRange = null;
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (!_heightUnknown)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Height Range', border: OutlineInputBorder()),
                value: _heightRange,
                items: [
                  'Under 2ft',
                  '2ft 0in - 2ft 6in',
                  '2ft 6in - 3ft 0in',
                  '3ft 0in - 3ft 6in',
                  '3ft 6in - 4ft 0in',
                  '4ft 0in - 4ft 6in',
                  '4ft 6in - 5ft 0in',
                  '5ft 0in - 5ft 6in',
                  '5ft 6in - 6ft 0in',
                  '6ft 0in - 6ft 6in',
                  '6ft 0in - 7ft 0in',
                  'Over 7ft'
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _heightRange = val),
                 validator: (val) => _heightUnknown ? null : (val == null ? 'Please select a height range' : null),
              ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Build', border: OutlineInputBorder()),
              value: _build,
              items: ['Slim', 'Average', 'Athletic', 'Heavy'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _build = val),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Skin Tone', border: OutlineInputBorder()),
              value: _skinTone,
              items: ['Fair', 'Light Brown', 'Medium Brown', 'Dark Brown', 'Very Dark', 'Albinism'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _skinTone = val),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Eye colour', border: OutlineInputBorder()),
              value: _eyeColor,
              items: ['Black', 'Dark Brown', 'Light Brown', 'Green', 'Blue', 'Other', 'Unknown'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _eyeColor = val),
            ),
            const SizedBox(height: 16),
            ChipInputField(
              labelText: 'Hair description',
              hintText: 'e.g. Short, Black, Braids...',
              initialChips: _hairList,
              onChanged: (val) => setState(() => _hairList = val),
            ),
            const SizedBox(height: 16),
            ChipInputField(
              labelText: 'Distinguishing marks',
              hintText: 'Scars, tattoos, birthmarks...',
              initialChips: _marksList,
              onChanged: (val) => setState(() => _marksList = val),
            ),
            const SizedBox(height: 16),
            ChipInputField(
              labelText: 'What were they last wearing?',
              hintText: 'e.g. Red shirt, Blue jeans...',
              initialChips: _clothingList,
              onChanged: (val) => setState(() => _clothingList = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisappearanceStep() {
    return _buildStepWrapper(
      Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 3 — Disappearance Details', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('When and where did this happen?'),
            const SizedBox(height: 24),
            
            _buildDateDropdowns(
              label: _isUnconscious ? 'Date found' : 'Date last seen',
              day: _seenDay,
              month: _seenMonth,
              year: _seenYear,
              onDayChanged: (val) => setState(() => _seenDay = val),
              onMonthChanged: (val) => setState(() => _seenMonth = val),
              onYearChanged: (val) => setState(() => _seenYear = val),
            ),
            SwitchListTile(
              title: const Text('Date is approximate'),
              value: _dateApproximate,
              onChanged: (val) => setState(() => _dateApproximate = val),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _timeSeenCtrl,
              decoration: InputDecoration(labelText: _isUnconscious ? 'Time found' : 'Time last seen', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            
            SearchChoices.single(
              items: NigeriaData.states.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              value: _stateSeen,
              hint: Text(_isUnconscious ? 'State found' : 'State last seen'),
              searchHint: const Text('Search state...'),
              onChanged: (val) {
                 setState(() {
                   _stateSeen = val;
                   _lgaSeen = null;
                 });
              },
              isExpanded: true,
              displayClearIcon: false,
              underline: Container(height: 1, color: Colors.grey),
              validator: (val) => val == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            SearchChoices.single(
              items: _stateSeen != null ? NigeriaData.statesAndLgas[_stateSeen!]!.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList() : [],
              value: _lgaSeen,
              hint: Text(_isUnconscious ? 'LGA found' : 'LGA last seen'),
              searchHint: const Text('Search LGA...'),
              onChanged: (val) => setState(() => _lgaSeen = val),
              isExpanded: true,
              displayClearIcon: false,
              readOnly: _stateSeen == null,
              underline: Container(height: 1, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            ChipInputField(
              labelText: 'Specific location description',
              hintText: 'e.g. Near Market, Yaba...',
              initialChips: _locationDescList,
              onChanged: (val) => setState(() => _locationDescList = val),
            ),
            const SizedBox(height: 16),
            
            ChipInputField(
              labelText: _isUnconscious ? 'How were they found?' : 'Circumstances',
              hintText: 'Describe what happened...',
              initialChips: _circumstancesList,
              onChanged: (val) => setState(() => _circumstancesList = val),
            ),
            const SizedBox(height: 16),
            
            if (!_isUnconscious) ...[
              TextFormField(
                controller: _occupationCtrl,
                decoration: const InputDecoration(labelText: 'Last known occupation/school', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
            ],
            
            ChipInputField(
              labelText: 'Medical conditions',
              hintText: 'e.g. Asthma, Dementia...',
              initialChips: _medicalList,
              onChanged: (val) => setState(() => _medicalList = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosStep() {
    return _buildStepWrapper(
      Form(
        key: _formKeys[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 4 — Photos', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Upload up to 3 photos of the missing person.'),
            const SizedBox(height: 24),
            
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!, width: 2, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.blue[700]),
                    const SizedBox(height: 12),
                    const Text('(Up to 3 photos)', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_existingPhotos.isNotEmpty || _selectedImages.isNotEmpty) ...[
              const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                   ..._existingPhotos.map((path) => _buildImagePreview(path, isExisting: true)),
                   ..._selectedImages.asMap().entries.map((entry) => _buildImagePreview(entry.value.path, isExisting: false, index: entry.key)),
                ],
              ),
            ],
            const SizedBox(height: 32),
            TextFormField(
              controller: _policeRefCtrl,
              decoration: const InputDecoration(labelText: 'Police report reference number (Optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(String path, {required bool isExisting, int? index}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: isExisting 
                ? NetworkImage(_supabase.storage.from('case_photos').getPublicUrl(path))
                : (kIsWeb ? NetworkImage(path) : FileImage(File(path))) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: () {
              if (isExisting) {
                setState(() => _existingPhotos.remove(path));
              } else {
                _removeImage(index!);
              }
            },
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildContactStep() {
    return _buildStepWrapper(
      Form(
        key: _formKeys[4],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 5 — Your Contact Details', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Your details are never shown publicly.'),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _registrantNameCtrl,
              decoration: const InputDecoration(labelText: 'Your full name', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _contactPhoneCtrl,
              decoration: const InputDecoration(labelText: 'Your phone number', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactEmailCtrl,
              decoration: const InputDecoration(labelText: 'Your email address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Relationship', border: OutlineInputBorder()),
              value: _relationship,
              items: ['Parent', 'Sibling', 'Spouse', 'Child', 'Other Family', 'Friend', 'Authority'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _relationship = val),
              validator: (val) => val == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Reported By', border: OutlineInputBorder()),
              value: _reportedByType,
              items: ['Family', 'Friend', 'Third Party', 'Authority/NGO'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _reportedByType = val),
              validator: (val) => val == null ? 'Required' : null,
            ),
            
            const SizedBox(height: 32),
            const Text('Secondary Contact (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _secondaryNameCtrl,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _secondaryPhoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return _buildStepWrapper(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Details', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          _buildReviewItem('Name', _fullNameUnknown ? 'Unknown' : _fullNameCtrl.text),
          _buildReviewItem('Gender', _gender ?? 'Unknown'),
          _buildReviewItem('Missing Date', (_seenYear != null) ? '$_seenYear-$_seenMonth-$_seenDay' : 'Unknown'),
          _buildReviewItem('State', _stateSeen ?? 'Unknown'),
          _buildReviewItem('Photos', '${_selectedImages.length} attached'),
          
          const SizedBox(height: 24),
          CheckboxListTile(
            title: const Text('I confirm the information is accurate.'),
            value: _consentGiven,
            onChanged: (val) => setState(() => _consentGiven = val ?? false),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _consentGiven && !_isUploading ? _submitReport : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.blue[900],
                foregroundColor: Colors.white,
              ),
              child: _isUploading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Submit Final Report', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildFinishedScreen() {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, size: 100, color: Colors.green),
              ),
              const SizedBox(height: 32),
              Text(
                'Report Submitted Successfully!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[900]),
              ),
              const SizedBox(height: 16),
              Text(
                'Thank you for your report. Our moderation team will review it shortly. Once approved, it will be visible on the platform.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/profile');
                  },
                  icon: const Icon(Icons.dashboard_outlined),
                  label: const Text('Go to My Dashboard', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return _buildFinishedScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Missing Person', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text('Step ${_currentStep + 1} of $_totalSteps', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await _saveDraft();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved.')));
            },
          )
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentStep + 1) / _totalSteps),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildIdentityStep(),
                _buildPhysicalStep(),
                _buildDisappearanceStep(),
                _buildPhotosStep(),
                _buildContactStep(),
                _buildReviewStep(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  TextButton(onPressed: _prevStep, child: const Text('Back'))
                else
                  const SizedBox(),
                
                if (_currentStep < _totalSteps - 1)
                  ElevatedButton(
                    onPressed: _nextStep, 
                    child: const Text('Next')
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
