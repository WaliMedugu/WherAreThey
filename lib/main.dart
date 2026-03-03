import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/report_case_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/search_results_screen.dart';
import 'screens/case_details_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/moderation_dashboard_screen.dart';
import 'services/notification_service.dart';
import 'data/notification_model.dart';
import 'utils/seo_util.dart';

// Repository to manage and listen to Auth state changes
class AuthRepository extends ChangeNotifier {
  AuthRepository() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  Session? get session => Supabase.instance.client.auth.currentSession;
  User? get user => Supabase.instance.client.auth.currentUser;
  bool get isAuthenticated => session != null;
}

final AuthRepository authRepository = AuthRepository();

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
     debugPrint("No .env file found, using platform environment variables if available.");
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://sbrhccewrzrpgkdtlxpf.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const WherAreTheyApp());
}

final _router = GoRouter(
  initialLocation: '/',
  refreshListenable: authRepository,
  redirect: (context, state) async {
    final bool loggedIn = authRepository.isAuthenticated;
    final bool isAuthRoute = state.matchedLocation == '/auth';

    // 1. Auth Guard: Redirect unauthenticated users to /auth for protected routes
    final protectedRoutes = ['/profile', '/admin', '/moderation', '/report', '/notifications'];
    if (!loggedIn && protectedRoutes.any((route) => state.matchedLocation.startsWith(route))) {
      return '/auth';
    }

    // 2. Already Logged In: Redirect from /auth to /
    if (loggedIn && isAuthRoute) {
      return '/';
    }

    // 3. Role-Based Guard: Only Admin for /admin, Admin/Moderator for /moderation
    if (loggedIn) {
      if (state.matchedLocation.startsWith('/admin') || state.matchedLocation.startsWith('/moderation')) {
        try {
          final res = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', authRepository.user!.id)
              .single();
          
          final role = res['role'] as String?;
          
          if (state.matchedLocation.startsWith('/admin') && role != 'admin') {
            return '/'; // Not an admin
          }
          if (state.matchedLocation.startsWith('/moderation') && role != 'admin' && role != 'moderator') {
            return '/'; // Not a moderator/admin
          }
        } catch (e) {
          return '/'; // Error fetching role
        }
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/moderation',
      builder: (context, state) => const ModerationDashboardScreen(),
    ),
    GoRoute(
      path: '/report',
      builder: (context, state) {
        final caseId = state.uri.queryParameters['id'];
        return ReportCaseScreen(caseId: caseId);
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) {
        final query = state.uri.queryParameters['q'] ?? '';
        return SearchResultsScreen(initialQuery: query);
      },
    ),
    GoRoute(
      path: '/case/:id',
      builder: (context, state) {
        // If passed via extra (internal navigation)
        if (state.extra != null && state.extra is Map<String, dynamic>) {
          return CaseDetailsScreen(person: state.extra as Map<String, dynamic>);
        }
        // If navigated via URL, CaseDetailsScreen currently expects a full Map.
        return CaseDetailsIdWrapper(id: state.pathParameters['id']!);
      },
    ),
  ],
);

class WherAreTheyApp extends StatelessWidget {
  const WherAreTheyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'WherAreThey - Missing Person Search',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8A7650),
          primary: const Color(0xFF8A7650),
          secondary: const Color(0xFF8E977D),
          tertiary: const Color(0xFFDBCEA5),
          surface: const Color(0xFFECE7D1),
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      routerConfig: _router,
    );
  }
}

// Wrapper for CaseDetailsScreen to fetch data if only ID is provided (e.g. direct URL)
class CaseDetailsIdWrapper extends StatelessWidget {
  final String id;
  const CaseDetailsIdWrapper({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Supabase.instance.client.from('cases').select().eq('id', id).single(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(body: Center(child: Text("Case not found")));
        }
        return CaseDetailsScreen(person: snapshot.data as Map<String, dynamic>);
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    SeoUtil.updateMeta(
      title: 'WherAreThey - Missing Person Search Nigeria',
      description: 'Search for and report missing persons in Nigeria. Help bring them home.',
    );
    _loadRecentCases();
  }

  Future<void> _loadRecentCases() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('cases')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10);
      
      if (mounted) {
        setState(() {
          _searchResults = (response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load recent cases: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    context.push('/results?q=$query');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 800;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  height: 32,
                  width: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "WherAreThey",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {},
              child: const Text("How it Works", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
            
            // Notifications Action
            StreamBuilder<List<NotificationModel>>(
              stream: _notificationService.subscribeToNotifications(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.hasData 
                    ? snapshot.data!.where((n) => !n.isRead).length 
                    : 0;
                
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white),
                      onPressed: () => context.push('/notifications'),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 8),

            // Profile Action
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                backgroundImage: NetworkImage('https://api.dicebear.com/7.x/identicon/png?seed=${Supabase.instance.client.auth.currentUser?.id}'),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Hero Section
              Stack(
                children: [
                  Container(
                    height: size.height * 0.7,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8A7650), Color(0xFF8E977D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.2,
                      child: Image.asset(
                        'assets/banner.png', 
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Text overlays removed as title is now in the banner image
                          const SizedBox(height: 100),
                          const SizedBox(height: 48),
                        // Search Bar
                        Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.blueGrey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onSubmitted: (_) => _performSearch(),
                                  decoration: const InputDecoration(
                                    hintText: "Enter name, age, or last seen location...",
                                    hintStyle: TextStyle(color: Colors.blueGrey),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (isDesktop)
                                ElevatedButton(
                                  onPressed: _performSearch,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8A7650),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text("Search Database"),
                                )
                              else
                                IconButton(
                                  onPressed: _performSearch,
                                  icon: const Icon(Icons.arrow_forward, color: Color(0xFF8A7650)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Results Section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Recent Cases",
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8A7650),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _isLoading 
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(),
                        ))
                      : GridView.builder(
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
                                             child: (person['photos'] != null && (person['photos'] as List).isNotEmpty)
                                                 ? Image.network(
                                                     'https://sbrhccewrzrpgkdtlxpf.supabase.co/storage/v1/object/public/case_photos/${person['photos'][0]}',
                                                     fit: BoxFit.cover,
                                                     errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 64, color: Colors.blueGrey),
                                                   )
                                                 : const Icon(Icons.person, size: 64, color: Colors.blueGrey),
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
                                                   Text(
                                                     "Details",
                                                     style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                                                   ),
                                                 ],
                                               ),
                                             ],
                                           ),
                                         ),
                                       ],
                                     ),
                                   ),
                                 );
                             },
                           ),
                   ],
                 ),
               ),
             ),
             
             // Footer
             Container(
               padding: const EdgeInsets.all(48),
               width: double.infinity,
               color: Colors.blueGrey.shade900,
               child: Column(
                 children: [
                   ClipOval(
                     child: Image.asset(
                       'assets/logo.png',
                       height: 48,
                       width: 48,
                       fit: BoxFit.cover,
                     ),
                   ),
                   const SizedBox(height: 16),
                   const Text(
                     "WherAreThey",
                     style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 12),
                   const Text(
                     "A collective effort to find our loved ones.",
                     style: TextStyle(color: Colors.white54),
                   ),
                   const SizedBox(height: 40),
                   const Divider(color: Colors.white24),
                   const SizedBox(height: 20),
                   const Text(
                     "© 2026 WherAreThey Foundation. Built for Nigeria.",
                     style: TextStyle(color: Colors.white30, fontSize: 12),
                   ),
                 ],
               ),
             ),
           ],
         ),
       ),
       floatingActionButton: FloatingActionButton.extended(
         onPressed: () => context.push('/report'),
         label: const Text("Report Missing"),
         icon: const Icon(Icons.add),
         backgroundColor: const Color(0xFF8E977D),
         foregroundColor: Colors.white,
       ),
     );
   }
 }
