import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/theme/app_theme.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/biometric_lock_screen.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/courses/presentation/courses_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/notification_preferences_screen.dart';
import '../features/checkin/presentation/checkin_screen.dart';
import '../features/checkin/presentation/qr_scan_screen.dart';
import '../features/messages/presentation/messages_screen.dart';
import '../core/services/biometric_service.dart';
import '../core/services/notification_service.dart';

class AttendXApp extends ConsumerStatefulWidget {
  const AttendXApp({super.key});

  @override
  ConsumerState<AttendXApp> createState() => _AttendXAppState();
}

class _AttendXAppState extends ConsumerState<AttendXApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasInBackground = false;
  bool _lockShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wire navigator key so notification taps can deep-link
    NotificationService.navigatorKey = _navigatorKey;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasInBackground = true;
      _lockShown = false;
    }
    if (state == AppLifecycleState.resumed &&
        _wasInBackground &&
        !_lockShown) {
      _wasInBackground = false;
      _maybeShowResumeLock();
    }
  }

  Future<void> _maybeShowResumeLock() async {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;
    final enabled = await BiometricService.isEnabled();
    if (!enabled) return;
    _lockShown = true;
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BiometricLockScreen(
          canSkipToLogin: true,
          onSuccess: () => _navigatorKey.currentState?.pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'AttendX',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/biometric-lock': (context) => BiometricLockScreen(
              canSkipToLogin: true,
              onSuccess: () => Navigator.pushReplacementNamed(
                  context, '/dashboard'),
            ),
        '/dashboard': (context) => const DashboardScreen(),
        '/history': (context) => const HistoryScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/courses': (context) => const CoursesScreen(),
        '/notification-preferences': (context) =>
            const NotificationPreferencesScreen(),
        '/messages': (context) => const MessagesScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/checkin') {
          return MaterialPageRoute(
            builder: (context) => const CheckinScreen(),
            settings: settings,
          );
        }
        if (settings.name == '/qr-scan') {
          return MaterialPageRoute(
            builder: (context) => const QrScanScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}