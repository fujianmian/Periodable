// lib/main.dart

// No changes to your imports, they are perfect.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/period_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'utils/constants.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'screens/auth/email_verification_screen.dart'; // Import the new screen

// lib/main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set device orientation before anything else
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // --- Start of Changes ---

  // 1. Initialize Firebase FIRST
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      // appleProvider: AppleProvider.appAttest,
    );
    debugPrint('✓ Firebase and App Check initialized successfully');
  } catch (e) {
    debugPrint('✗ Firebase initialization error: $e');
  }

  // 2. Initialize AppConfig SECOND (now that Firebase is ready)
  try {
    await AppConfig.initialize();
    debugPrint('✓ AppConfig initialized successfully');
  } catch (e) {
    debugPrint('✗ AppConfig initialization error: $e');
  }

  // --- End of Changes ---

  // Initialize other services
  try {
    final databaseService = DatabaseService();
    await databaseService.init();

    final notificationService = NotificationService();
    await notificationService.init();
    debugPrint('✓ Services initialized successfully');
  } catch (e) {
    debugPrint('✗ Services initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..init(),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, PeriodProvider>(
          create: (context) => PeriodProvider(
            context.read<SettingsProvider>(),
          )..init(),
          update: (context, settings, previousPeriodProvider) {
            previousPeriodProvider!.updateDependencies(settings);
            return previousPeriodProvider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: AppColors.background,
              fontFamily: 'Inter',
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
              ),
            ),
            home: const AppRouter(), // This remains the entry point
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const MainScreen(),
              '/settings': (context) => const SettingsScreen(),
              // You might need to add other routes like forgot-password if you have them
            },
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const Scaffold(
                  body: Center(child: Text('Route not found')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ⭐ UPDATE: Converted to StatefulWidget to manage state synchronization
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncUserEmail();
  }

  void _syncUserEmail() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final periodProvider = Provider.of<PeriodProvider>(context, listen: false);

    final user = authProvider.currentUser;
    final storedEmail = settingsProvider.settings.userEmail;

    if (user != null && user.email != null && user.email != storedEmail) {
      debugPrint('[AppRouter] Syncing user email: ${user.email}');

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await settingsProvider.updateUserEmail(user.email!);

        // Initialize period provider with user email
        await periodProvider.init(userEmail: user.email);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isAuthenticated) {
          if (!authProvider.isEmailVerified) {
            return EmailVerificationScreen(
              email: authProvider.currentUser?.email ?? '',
            );
          }
          return const MainScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

// No changes needed for MainScreen
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CalendarScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Statistics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
