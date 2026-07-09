import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/app_state.dart';
import 'models/couple_model.dart';
import 'models/language_provider.dart';
import 'models/memories_provider.dart';
import 'models/reminders_provider.dart';
import 'models/user_model.dart';
import 'models/weekly_ideas_provider.dart';
import 'screens/couple_setup_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ideas_screen.dart';
import 'screens/last_time_screen.dart';
import 'screens/login_screen.dart';
import 'screens/name_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/onboarding_preferences.dart';
import 'screens/splash_screen.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    riverpod.ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => WeeklyIdeasProvider()),
          ChangeNotifierProvider(create: (_) => MemoriesProvider()),
          ChangeNotifierProvider(create: (_) => RemindersProvider()),
        ],
        child: const UsApp(),
      ),
    ),
  );
}

class UsApp extends StatelessWidget {
  const UsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'US',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

// ── AuthGate ───────────────────────────────────────────────────────────────────

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = authSnap.data;
        if (user == null) return const LoginScreen();

        // Authenticated — watch the user document.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            if (userSnap.hasError) {
              debugPrint('[AuthGate] user stream error: ${userSnap.error}');
              return const LoginScreen();
            }

            final userDoc = userSnap.data;

            // Document not yet written (race between auth callback and
            // the Firestore write in _handleAuthSuccess).
            if (userDoc == null || !userDoc.exists) {
              return const SplashScreen();
            }

            final userData = UserModel.fromFirestore(userDoc);

            // Email verification gate — only for new email/password registrations.
            // Existing users and federated (Google/Apple) users never have this flag.
            if (userData.needsEmailVerification) {
              return EmailVerificationScreen(user: user);
            }

            // No name yet — must set before anything else.
            if (userData.displayName.isEmpty) {
              return NameScreen(uid: user.uid);
            }

            final coupleId = userData.coupleId;

            // No couple yet — let them in with static fallback data.
            // The invite banner on HomeScreen guides them to connect a partner.
            if (coupleId == null || coupleId.isEmpty) {
              return const MainShell();
            }

            // Has coupleId — verify the couple's status.
            return _CoupleGate(uid: user.uid, coupleId: coupleId);
          },
        );
      },
    );
  }
}

// ── _CoupleGate ────────────────────────────────────────────────────────────────

class _CoupleGate extends StatefulWidget {
  final String uid;
  final String coupleId;

  const _CoupleGate({required this.uid, required this.coupleId});

  @override
  State<_CoupleGate> createState() => _CoupleGateState();
}

class _CoupleGateState extends State<_CoupleGate> {
  bool _clearedStale = false;
  bool _onboardingCheckStarted = false;
  bool? _onboardingDone; // null = check pending, true/false = result known
  // Created once so StreamBuilder never re-subscribes on setState rebuilds.
  late final Stream<CoupleModel?> _coupleStream;

  @override
  void initState() {
    super.initState();
    _coupleStream = FirestoreService.watchCouple(widget.coupleId);
  }

  Future<void> _checkOnboarding() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('couples')
          .doc(widget.coupleId)
          .collection('settings')
          .doc('main')
          .get();
      if (!mounted) return;
      setState(() {
        _onboardingDone = snap.data()?['onboardingDone'] == true;
      });
    } catch (e) {
      debugPrint('[CoupleGate] onboarding check failed: $e');
      if (!mounted) return;
      setState(() => _onboardingDone = false);
    }
  }

  Future<void> _finishOnboarding(OnboardingPreferences prefs) async {
    await FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('settings')
        .doc('main')
        .set({
      'onboardingDone': true,
      'isParent': prefs.isParent,
      'place': prefs.place,
      'pace': prefs.pace,
      'availableTime': prefs.time,
      'bedtimeHour': prefs.bedtime.hour,
      'bedtimeMinute': prefs.bedtime.minute,
    }, SetOptions(merge: true));
    if (!mounted) return;
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CoupleModel?>(
      stream: _coupleStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snap.hasError) {
          debugPrint('[CoupleGate] couple stream error: ${snap.error}');
          if (!_clearedStale) {
            _clearedStale = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.uid)
                  .update({'coupleId': null}).catchError((_) {});
            });
          }
          return const SplashScreen();
        }

        final couple = snap.data;

        if (kDebugMode) {
          debugPrint('[CoupleGate] stream emit → status=${couple?.status}, isActive=${couple?.isActive}, members=${couple?.members.length ?? 0}, _onboardingDone=$_onboardingDone');
        }

        // Couple document missing — stale coupleId on user doc.
        // Clear it and wait for AuthGate to re-route.
        if (couple == null) {
          if (!_clearedStale) {
            _clearedStale = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.uid)
                  .update({'coupleId': null}).catchError((_) {});
            });
          }
          return const SplashScreen();
        }

        if (couple.isActive) {
          // Both partners connected — check once whether onboarding is done.
          if (!_onboardingCheckStarted) {
            _onboardingCheckStarted = true;
            _checkOnboarding();
          }

          if (kDebugMode) {
            debugPrint('[CoupleGate] isActive=true → _onboardingCheckStarted=$_onboardingCheckStarted, _onboardingDone=$_onboardingDone');
          }

          if (_onboardingDone == null) return const SplashScreen();
          if (_onboardingDone == false) {
            return OnboardingPreferencesScreen(onFinish: _finishOnboarding);
          }

          context.read<WeeklyIdeasProvider>().init(widget.coupleId);
          context.read<MemoriesProvider>().init(widget.coupleId);
          return Consumer<WeeklyIdeasProvider>(
            builder: (ctx, ideasProvider, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: ideasProvider.initialized
                    ? const MainShell()
                    : const SplashScreen(),
              );
            },
          );
        }

        // Pending couple — not reachable in normal flow (coupleId is only
        // written when active), but handle defensively.
        return CoupleSetupScreen(
          currentUserId: widget.uid,
          onCoupleActive: () {},
        );
      },
    );
  }
}

// ── MainShell ──────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String _lastCheckedCoupleId = '';

  final List<GlobalKey<NavigatorState>> _tabNavKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  static const _tabScreens = [
    HomeScreen(),
    LastTimeScreen(),
    IdeasScreen(),
    PlanScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initFcm();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context);
    final coupleId = appState.coupleId;
    final userId = appState.userId;
    if (coupleId.isNotEmpty && userId.isNotEmpty && coupleId != _lastCheckedCoupleId) {
      _lastCheckedCoupleId = coupleId;
      context.read<WeeklyIdeasProvider>().checkIncomingRequests(coupleId, userId);
      context.read<WeeklyIdeasProvider>().checkOutgoingRequests(coupleId, userId);
    }
  }

  Future<void> _initFcm() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      FirestoreService.saveFcmToken(uid, token).catchError((_) {});
    }
    messaging.onTokenRefresh.listen((newToken) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        FirestoreService.saveFcmToken(currentUid, newToken).catchError((_) {});
      }
    });

    // Init local notifications plugin + create Android channels
    await NotificationService().init();

    // Foreground: no system banner — silently refresh so the stream fires and
    // PendingIdeaCard mounts, which auto-opens the modal via its initState hook.
    FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      final coupleId = appState.coupleId;
      final userId = appState.userId;
      if (coupleId.isNotEmpty && userId.isNotEmpty) {
        context.read<WeeklyIdeasProvider>().checkIncomingRequests(coupleId, userId);
      }
      if (message.data['type'] == 'plan_cancelled') {
        final body = message.notification?.body ?? '';
        if (body.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body),
            backgroundColor: AppTheme.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    });

    // Tap: app was in background when notification arrived
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });

    // Tap: app was terminated when notification arrived
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial.data);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      if (data['type'] == 'idea_request') {
        final coupleId = appState.coupleId;
        final userId = appState.userId;
        if (coupleId.isNotEmpty && userId.isNotEmpty) {
          context.read<WeeklyIdeasProvider>().checkIncomingRequests(coupleId, userId);
        }
        appState.requestTabNavigation(3);
      } else if (data['type'] == 'idea_accepted') {
        appState.requestTabNavigation(3);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final appState = context.watch<AppState>();
    final pendingIdeas = context.watch<WeeklyIdeasProvider>().pendingIncomingCount;
    if (appState.pendingTabIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentIndex = appState.pendingTabIndex!);
        appState.consumeTabNavigation();
      });
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _tabNavKeys[_currentIndex].currentState;
        if (nav != null && nav.canPop()) nav.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            _tabScreens.length,
            (i) => Navigator(
              key: _tabNavKeys[i],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => _tabScreens[i],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: const Border(
              top: BorderSide(color: AppTheme.divider, width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textPrimary.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              backgroundColor: Colors.transparent,
              elevation: 0,
              enableFeedback: false,
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home_rounded),
                  label: s.navHome,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.access_time_outlined),
                  activeIcon: const Icon(Icons.access_time_rounded),
                  label: s.navLastTime,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  activeIcon: const Icon(Icons.lightbulb_rounded),
                  label: s.navIdeas,
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: pendingIdeas > 0,
                    label: Text('$pendingIdeas'),
                    child: const Icon(Icons.calendar_today_outlined),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: pendingIdeas > 0,
                    label: Text('$pendingIdeas'),
                    child: const Icon(Icons.calendar_today_rounded),
                  ),
                  label: s.navPlan,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
