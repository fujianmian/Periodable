// No changes to your imports, they are perfect.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // ✅ IMPROVEMENT: Import for the Timer
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

void main() async {
  final model =
      GenerativeModel(model: 'gemini-2.5-pro', apiKey: AppConfig.geminiApiKey);
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      // appleProvider: AppleProvider.appAttest,
    );
    debugPrint('✓ Firebase and App Check initialized successfully');
  } catch (e) {
    debugPrint('✗ Firebase initialization error: $e');
  }

  // ✅ IMPROVEMENT: Add try-catch for robustness, similar to Firebase init
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
        // ✅ IMPROVEMENT: Simplified and safer ChangeNotifierProxyProvider
        ChangeNotifierProxyProvider<SettingsProvider, PeriodProvider>(
          create: (context) => PeriodProvider(
            context.read<SettingsProvider>(),
          )..init(), // init() is only called here, once.
          update: (context, settings, previousPeriodProvider) {
            // The previous provider is guaranteed to exist.
            // Update its dependencies and return it.
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
            home: const AppRouter(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const MainScreen(),
              '/settings': (context) => const SettingsScreen(),
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

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // ✅ IMPROVEMENT: Show a loading screen during initial auth check
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
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

        // Default to login if not authenticated
        return const LoginScreen();
      },
    );
  }
}

// ✅ IMPROVEMENT: Converted to StatefulWidget for Timer management
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start a timer to check for verification every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      context.read<AuthProvider>().checkEmailVerified();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        actions: [
          // ✅ IMPROVEMENT: Add a sign out button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'A verification email has been sent to ${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Resend Button
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            await authProvider.sendEmailVerification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Verification email sent')),
                              );
                            }
                          },
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Resend Email'),
                  );
                },
              ),
              const SizedBox(height: 16),
              // "I have verified" is less critical now due to the timer, but can be kept for manual checks
              TextButton(
                  onPressed: () async {
                    final isVerified =
                        await context.read<AuthProvider>().checkEmailVerified();
                    if (context.mounted && isVerified) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Email verified successfully!')),
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Email not yet verified.')),
                      );
                    }
                  },
                  child: const Text("I've Verified, Check Now")),
            ],
          ),
        ),
      ),
    );
  }
}

// No changes needed for MainScreen, it's already well-implemented.
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
