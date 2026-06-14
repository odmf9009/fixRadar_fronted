import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/user_model.dart';
import '../../core/models/service_request.dart';
import '../../core/models/filter_model.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/role_selection_screen.dart';
import '../../presentation/screens/onboarding_screen.dart';
import '../../presentation/screens/main_navigation_screen.dart';
import '../../presentation/screens/object_detail_screen.dart';
import '../../presentation/screens/all_nearby_objects_screen.dart';
import '../../presentation/screens/technicians_list_screen.dart';
import '../../presentation/screens/technicians_directory_screen.dart';
import '../../presentation/screens/favorite_technicians_screen.dart';
import '../../presentation/screens/top_technicians_screen.dart';
import '../../presentation/screens/chat_screen.dart';
import '../../presentation/screens/filters_screen.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/client_requests_screen.dart';
import '../../presentation/screens/client_responders_list_screen.dart';
import '../../presentation/screens/technician_quotes_screen.dart';
import '../../presentation/screens/technician_clients_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../presentation/screens/public_profile_screen.dart';
import '../../presentation/screens/my_posts_screen.dart';
import '../../presentation/screens/admin_panel_screen.dart';
import '../../presentation/screens/edit_technician_profile_screen.dart';
import '../../presentation/screens/manage_portfolio_screen.dart';
import '../../presentation/screens/achievements_screen.dart';
import '../../presentation/screens/activity_history_screen.dart';
import '../../presentation/screens/referral_screen.dart';
import '../../presentation/screens/rewards_screen.dart';
import '../../presentation/screens/publish_service_request_screen.dart';
import '../../presentation/screens/alerts_screen.dart';
import '../../presentation/screens/ranking_screen.dart';
import '../../presentation/screens/community_stats_screen.dart';
import '../../presentation/screens/premium_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/notification_settings_screen.dart';
import '../../presentation/screens/search_radius_screen.dart';
import '../../presentation/screens/privacy_settings_screen.dart';
import '../../presentation/screens/privacy_policy_screen.dart';
import '../../presentation/screens/third_party_licenses_screen.dart';
import '../../presentation/screens/language_settings_screen.dart';
import '../../presentation/screens/terms_screen.dart';
import '../../presentation/screens/about_screen.dart';
import '../../presentation/screens/help_support_screen.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String roleSelection = '/role-selection';
  static const String home = '/home';
  static const String publish = '/publish';
  static const String premium = '/premium';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String requestDetail = '/request-detail';
  static const String techniciansList = '/technicians-list';
  static const String techniciansDirectory = '/technicians-directory';
  static const String myPosts = '/my-posts';
  static const String adminPanel = '/admin-panel';
  static const String filters = '/filters';
  static const String ranking = '/ranking';
  static const String topTechnicians = '/top-technicians';
  static const String allNearby = '/all-nearby';
  static const String chat = '/chat';
  static const String dashboard = '/dashboard';
  static const String clientRequests = '/client-requests';
  static const String notificationSettings = '/notification-settings';
  static const String searchRadiusSettings = '/search-radius-settings';
  static const String privacySettings = '/privacy-settings';
  static const String privacyPolicy = '/privacy-policy';
  static const String licenses = '/licenses';
  static const String languageSettings = '/language-settings';
  static const String terms = '/terms';
  static const String about = '/about';
  static const String helpSupport = '/help-support';
  static const String publicProfile = '/public_profile';
  static const String favoriteTechnicians = '/favorite-technicians';
  static const String achievements = '/achievements';
  static const String editTechProfile = '/edit-tech-profile';
  static const String managePortfolio = '/manage-portfolio';
  static const String activityHistory = '/activity-history';
  static const String communityStats = '/community-stats';
  static const String referrals = '/referrals';
  static const String rewards = '/rewards';
  static const String alerts = '/alerts';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    onboarding: (context) => const OnboardingScreen(),
    login: (context) => const LoginScreen(),
    roleSelection: (context) => const RoleSelectionScreen(),
    home: (context) => const MainNavigationScreen(),
    publish: (context) => const PublishServiceRequestScreen(),
    premium: (context) => const PremiumScreen(),
    settings: (context) => const SettingsScreen(),
    profile: (context) => const ProfileScreen(),
    dashboard: (context) => const DashboardScreen(),
    clientRequests: (context) => const ClientRequestsScreen(),
    notificationSettings: (context) => const NotificationSettingsScreen(),
    searchRadiusSettings: (context) => const SearchRadiusScreen(),
    privacySettings: (context) => const PrivacySettingsScreen(),
    privacyPolicy: (context) => const PrivacyPolicyScreen(),
    licenses: (context) => const ThirdPartyLicensesScreen(),
    languageSettings: (context) => const LanguageSettingsScreen(),
    terms: (context) => const TermsScreen(),
    about: (context) => const AboutScreen(),
    helpSupport: (context) => const HelpSupportScreen(),
    requestDetail: (context) => const RequestDetailScreen(),
    myPosts: (context) => const MyPostsScreen(),
    adminPanel: (context) => const AdminPanelScreen(),
    filters: (context) => FiltersScreen(initialFilters: FilterModel()),
    ranking: (context) => const RankingScreen(),
    topTechnicians: (context) => const TopTechniciansScreen(),
    achievements: (context) => const AchievementsScreen(),
    activityHistory: (context) => const ActivityHistoryScreen(),
    communityStats: (context) => const CommunityStatsScreen(),
    referrals: (context) => const ReferralScreen(),
    rewards: (context) => const RewardsScreen(),
    alerts: (context) => const AlertsScreen(),
    favoriteTechnicians: (context) => const FavoriteTechniciansScreen(),
    techniciansDirectory: (context) => const TechniciansDirectoryScreen(),
    techniciansList: (context) {
      final request = ModalRoute.of(context)!.settings.arguments as ServiceRequest;
      return TechniciansListScreen(request: request);
    },
    allNearby: (context) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return AllNearbyRequestsScreen(
        requests: args['requests'] as List<ServiceRequest>,
        currentPosition: args['position'] as Position?,
      );
    },
    chat: (context) {
      final args = ModalRoute.of(context)!.settings.arguments as ServiceRequest;
      return ChatScreen(request: args);
    },
    publicProfile: (context) {
      final userId = ModalRoute.of(context)!.settings.arguments as String;
      return PublicProfileScreen(userId: userId);
    },
    editTechProfile: (context) {
      final user = ModalRoute.of(context)!.settings.arguments as UserModel;
      return EditTechnicianProfileScreen(user: user);
    },
    managePortfolio: (context) => const ManagePortfolioScreen(),
  };
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      // Sync with backend to ensure the user exists in MongoDB
      await AuthService().syncCurrentUser();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo_centro.png', width: 120, height: 120),
            const SizedBox(height: 24),
            const Text(
              'FixRadar',
              style: TextStyle(
                color: Color(0xFFFF8A00),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Color(0xFFFF8A00)),
          ],
        ),
      ),
    );
  }
}
