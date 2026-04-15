import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'services/providers.dart';
import 'services/firebase_service.dart';
import 'utils/connectivity_service.dart';
import 'models/models.dart';

// Screens — Auth
import 'screens/auth/splash_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';

// Screens — Customer
import 'screens/customer/customer_scaffold.dart';
import 'screens/customer/customer_orders_screen.dart';
import 'screens/customer/new_request_screen.dart';
import 'screens/customer/request_tracking_screen.dart';
import 'screens/customer/subscription_screen.dart';
import 'screens/customer/referral_screen.dart';

// Screens — Provider
import 'screens/provider/provider_screens.dart';
import 'screens/provider/provider_onboarding_screen.dart'; // TÂCHE 5

// Screens — Admin
import 'screens/admin/admin_screens.dart';

// Chat
import 'screens/chat/chat_screen.dart';

// ── Background FCM handler (top-level, required by Firebase) ──
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.bg3,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // [#4] FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Crashlytics
  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Firestore offline persistence — 100 MB cap
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 100 * 1024 * 1024,
  );

  // [#12] Analytics — enable collection
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(!kDebugMode);

  // FIX: Initialise le service de connectivité avant le lancement
  ConnectivityService.instance.initialize();

  runApp(const ChoflyApp());
}

class ChoflyApp extends StatefulWidget {
  const ChoflyApp({super.key});

  @override
  State<ChoflyApp> createState() => _ChoflyAppState();
}

class _ChoflyAppState extends State<ChoflyApp> {
  final _notificationService = NotificationService();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  // [#4] Init FCM — permissions + token + handlers
  Future<void> _initFCM() async {
    await _notificationService.initialize();

    // Foreground notification → SnackBar
    NotificationService.setupForegroundHandler((title, body, data) {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              if (body.isNotEmpty)
                Text(body,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          action: _buildNotifAction(data),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    // Background tap → navigate
    NotificationService.setupBackgroundTapHandler((data) {
      _handleNotifTap(data);
    });

    // App opened from terminated state via notif
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleNotifTap(initial.data);
  }

  SnackBarAction? _buildNotifAction(Map<String, dynamic> data) {
    final requestId = data['requestId'] as String?;
    if (requestId == null) return null;
    return SnackBarAction(
      label: 'Voir',
      textColor: AppTheme.green,
      onPressed: () => _navigatorKey.currentState?.pushNamed(
        '/customer/request-detail',
        arguments: requestId,
      ),
    );
  }

  void _handleNotifTap(Map<String, dynamic> data) {
    final requestId = data['requestId'] as String?;
    if (requestId != null) {
      _navigatorKey.currentState?.pushNamed(
        '/customer/request-detail',
        arguments: requestId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),  // [#2]
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'CHOFLY',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,       // [#2]
            darkTheme: AppTheme.dark,    // [#2]
            themeMode: themeProvider.themeMode,  // [#2]
            navigatorKey: _navigatorKey,
            navigatorObservers: [
              // [#12] Analytics navigator observer
              FirebaseAnalyticsObserver(
                  analytics: FirebaseAnalytics.instance),
            ],
            initialRoute: '/',
            onGenerateRoute: _generateRoute,
            builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return ConnectivityWrapper(child: child);
          },
          );
        },
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Auth
      case '/':
        return _fade(const SplashScreen());
      case '/onboarding':
        return _slide(const OnboardingScreen());
      case '/login':
        return _slide(const LoginScreen());
      case '/setup-profile':
        return _slide(const SetupProfileScreen());

      // ── Customer
      case '/customer/home':
        return _fade(const CustomerScaffold());
      case '/customer/new-request':
        final cat = settings.arguments as ServiceCategory?;
        return _slide(NewRequestScreen(initialCategory: cat));
      case '/customer/request-tracking':
        final id = settings.arguments as String? ?? '';
        if (id.isEmpty) return _fade(const CustomerScaffold());
        return _slide(RequestTrackingScreen(requestId: id));
      case '/customer/request-detail':
        final id2 = settings.arguments as String? ?? '';
        if (id2.isEmpty) return _fade(const CustomerScaffold());
        return _slide(RequestTrackingScreen(requestId: id2));
      case '/customer/profile':
        return _slide(const CustomerProfileScreen());
      case '/customer/orders':
        return _slide(const CustomerOrdersScreen());
      case '/customer/subscription':
        return _slide(const SubscriptionScreen());
      case '/customer/referral':                 // [#10]
        return _slide(const ReferralScreen());

      // ── Chat  [#3]
      case '/chat':
        final args = settings.arguments as Map<String, String>?;
        if (args == null) return _fade(const CustomerScaffold());
        return _slide(ChatScreen(
          requestId: args['requestId'] ?? '',
          otherPartyName: args['otherPartyName'] ?? 'Technicien',
        ));

      // ── Provider
      case '/provider/onboarding':
        return _buildRoute(const ProviderOnboardingScreen());
      case '/provider/setup':
        return _slide(const ProviderSetupScreen());
      case '/provider/pending':
        return _fade(const ProviderPendingScreen());
      case '/provider/home':
        return _fade(const ProviderScaffold());

      // ── Admin
      case '/admin':
        return _fade(const AdminScaffold());

      default:
        return _fade(const SplashScreen());
    }
  }

  static PageRoute _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );

  static PageRoute _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(
        begin: const Offset(1.0, 0.0), end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(
          position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 280),
  );
}
