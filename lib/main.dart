import 'dart:async';
import 'dart:ui';
import 'dart:async' as async;

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
import 'providers/developer_options_provider.dart';
import 'widgets/developer_options_warning_dialog.dart';
import 'services/background_tracking_service.dart';
import 'services/tracking_state_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/profile/force_password_screen.dart';
import 'services/api_service.dart';
import 'services/persistent_notification_service.dart';
import 'widgets/update_dialog.dart';
import 'models/version_model.dart';
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

    await BackgroundTrackingService.initialize();
    await PersistentNotificationService.initialize();

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
        ChangeNotifierProvider(create: (_) => DeveloperOptionsProvider()),
      ],
      child: AppLifecycleHandler(
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
          home: const DeveloperOptionsWrapper(child: AuthWrapper()),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/attendance': (context) => const AttendanceScreen(),
          },
        ),
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

class AppLifecycleHandler extends StatefulWidget {
  const AppLifecycleHandler({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<AppLifecycleHandler> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TrackingStateService.setAppForeground(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setForeground(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TrackingStateService.setAppForeground(false);
    super.dispose();
  }

  void _setForeground(bool isForeground) {
    TrackingStateService.setAppForeground(isForeground);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    attendanceProvider.setForegroundActive(isForeground);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    _setForeground(isForeground);

    // Recover services when app comes back from background/force close
    if (state == AppLifecycleState.resumed) {
      _recoverServicesAfterForceClose();
    }
  }

  Future<void> _recoverServicesAfterForceClose() async {
    debugPrint('[AppLifecycleHandler] 🔄 Recovering services after app resume...');

    try {
      // 1. Re-initialize persistent notification if needed
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      await attendanceProvider.loadAttendance(); // This will restore persistent notification

      // 2. Re-check background tracking status
      final trackingState = await TrackingStateService.getTrackingState();
      if (trackingState != null) {
        debugPrint('[AppLifecycleHandler] 🔄 Background tracking was active, restarting...');
        await BackgroundTrackingService.ensureRunning();
      }

      // 3. Re-sync any pending data
      await _syncPendingData();

      debugPrint('[AppLifecycleHandler] ✅ Services recovered successfully');
    } catch (e) {
      debugPrint('[AppLifecycleHandler] ❌ Failed to recover services: $e');
    }
  }

  Future<void> _syncPendingData() async {
    try {
      // Sync pending activities
      final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
      await activityProvider.syncPendingActivities();

      // Location logs will be synced automatically by AttendanceProvider when needed
      debugPrint('[AppLifecycleHandler] ✅ Pending data synced');
    } catch (e) {
      debugPrint('[AppLifecycleHandler] ❌ Failed to sync pending data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class DeveloperOptionsWrapper extends StatefulWidget {
  final Widget child;

  const DeveloperOptionsWrapper({super.key, required this.child});

  @override
  State<DeveloperOptionsWrapper> createState() => _DeveloperOptionsWrapperState();
}

class _DeveloperOptionsWrapperState extends State<DeveloperOptionsWrapper> with WidgetsBindingObserver {
  bool _dialogShown = false;
  Timer? _periodicCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Cek developer options saat widget pertama kali dibuat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeveloperOptions();
      _startPeriodicCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cek developer options setiap kali app kembali ke foreground
    if (state == AppLifecycleState.resumed) {
      _checkDeveloperOptions();
    }
  }

  void _startPeriodicCheck() {
    // Cek developer options setiap 30 detik
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkDeveloperOptions();
      }
    });
  }

  void _checkDeveloperOptions() {
    final developerProvider = Provider.of<DeveloperOptionsProvider>(context, listen: false);
    if (developerProvider.isDeveloperOptionsEnabled && !_dialogShown && mounted) {
      _dialogShown = true;
      DeveloperOptionsWarningDialog.show(context).then((_) {
        // Dialog ditutup, reset flag agar bisa ditampilkan lagi jika masih aktif
        _dialogShown = false;
        // Cek ulang setelah dialog ditutup
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            developerProvider.refreshStatus().then((_) {
              _checkDeveloperOptions();
            });
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeveloperOptionsProvider>(
      builder: (context, developerProvider, child) {
        // Cek developer options setiap kali provider berubah
        if (developerProvider.isDeveloperOptionsEnabled && !_dialogShown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkDeveloperOptions();
          });
        }

        return widget.child;
      },
      child: widget.child,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  void _showUpdateDialog(BuildContext context, VersionData versionData, bool isRequired) {
    UpdateDialog.show(
      context: context,
      versionData: versionData,
      isRequired: isRequired,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Set version check callback
        authProvider.setVersionCheckCallback((updateAvailable, updateRequired, versionData) {
          if (updateAvailable && versionData != null) {
            // Show update dialog
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showUpdateDialog(context, versionData, updateRequired);
            });
          }
        });

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

          // Pastikan background tracking service running jika ada attendance aktif
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final attendanceProvider = Provider.of<AttendanceProvider>(navigatorKey.currentContext!, listen: false);
            attendanceProvider.ensureBackgroundTracking();
          });

          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
