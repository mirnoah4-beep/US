import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'models/language_provider.dart';
import 'models/reminders_provider.dart';
import 'models/weekly_ideas_provider.dart';
import 'screens/home_screen.dart';
import 'screens/last_time_screen.dart';
import 'screens/ideas_screen.dart';
import 'screens/plan_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Requires google-services.json (Android) and GoogleService-Info.plist (iOS).
    // App runs without them; Firebase features degrade gracefully until added.
    await Firebase.initializeApp();
  } catch (_) {}
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => WeeklyIdeasProvider()),
        ChangeNotifierProvider(create: (_) => RemindersProvider()),
      ],
      child: const UsApp(),
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
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // One navigator key per tab so showModalBottomSheet(useRootNavigator: false)
  // finds the tab's own navigator and the sheet stays within the body area,
  // leaving the bottom nav bar visible.
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
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final appState = context.watch<AppState>();
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
                  icon: const Icon(Icons.calendar_today_outlined),
                  activeIcon: const Icon(Icons.calendar_today_rounded),
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
