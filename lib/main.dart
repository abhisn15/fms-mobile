import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/activity_provider.dart';
import 'providers/request_provider.dart';
import 'providers/connectivity_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/profile/force_password_screen.dart';
import 'services/api_service.dart';
import 'services/error_reporting_service.dart';

// Global navigator key untuk akses navigator dari mana saja
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      ErrorReportingService().reportFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReportingService().reportError(error, stack, isFatal: true);
      return true;
    };

    // Load environment variables
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // Silently use default configuration
    }

    // Initialize Indonesian locale data for DateFormat
    await initializeDateFormatting('id_ID', null);

    runApp(const MyApp());
  }, (error, stack) {
    ErrorReportingService().reportError(error, stack, isFatal: true);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Setup auto logout callback setelah widget tree siap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ApiService().setSessionExpiredCallback(() {
        debugPrint('[App] Session expired - Auto logout triggered');
        _handleAutoLogout();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => ShiftProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
      ],
      child: MaterialApp(
        title: 'Atenim Mobile',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey, // Global navigator key untuk auto logout
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('id', 'ID'),
          Locale('en', 'US'),
        ],
        locale: const Locale('id', 'ID'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/attendance': (context) => const AttendanceScreen(),
        },
      ),
    );
  }

  void _handleAutoLogout() {
    debugPrint('[App] ===== AUTO LOGOUT TRIGGERED =====');
    
    // Use navigator key context untuk akses provider
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[App] ⚠ Navigator context not available, retrying in 500ms...');
      // Retry setelah navigator siap
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleAutoLogout();
      });
      return;
    }
    
    debugPrint('[App] Executing auto logout...');
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.logout().then((_) {
        debugPrint('[App] Logout completed, redirecting to login...');
        // Wait a bit untuk memastikan state sudah update
        Future.delayed(const Duration(milliseconds: 200), () {
          final navContext = navigatorKey.currentContext;
          if (navContext != null) {
            Navigator.of(navContext).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
            // Show notification
            ScaffoldMessenger.of(navContext).showSnackBar(
              const SnackBar(
                content: Text('Sesi Anda telah berakhir. Silakan login kembali.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            debugPrint('[App] ✓ Redirected to login screen');
          } else {
            debugPrint('[App] ⚠ Navigator context lost during redirect');
          }
        });
      }).catchError((error) {
        debugPrint('[App] ✗ Error during auto logout: $error');
      });
    } catch (e) {
      debugPrint('[App] ✗ Exception during auto logout: $e');
    }
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Auto redirect ke login jika tidak authenticated
        if (!authProvider.isLoading && !authProvider.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (navigatorKey.currentContext != null) {
              Navigator.of(navigatorKey.currentContext!).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            }
          });
        }
        
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isAuthenticated) {
          final user = authProvider.user;
          final needsPasswordSetup =
              (user?.hasPassword == false) || (user?.needsPasswordChange == true);
          if (needsPasswordSetup) {
            return const ForcePasswordScreen();
          }
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
