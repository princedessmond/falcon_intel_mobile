import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/biometric_offer.dart';
import 'features/auth/login_screen.dart';
import 'features/news/news_screen.dart';
import 'features/social/social_screen.dart';
import 'features/alerts/alerts_screen.dart';
import 'features/watchlist/watchlist_screen.dart';
import 'features/settings/settings_screen.dart';

/// Badge on the Alerts tab: unchecked alerts the Alerts screen actually lists
/// (news + social). The server's /alerts/count also includes dark-web alerts
/// that the app doesn't show, which made the badge promise alerts nobody
/// could open. Fetched separately so refreshing it doesn't reload the screen.
final navAlertCountProvider = FutureProvider<int>((ref) async {
  try {
    final alerts = await fetchAppAlerts('all');
    return alerts.where(isOpenAlert).length;
  } catch (_) {}
  return 0;
});

/// One navigator per bottom tab, so each tab keeps its own history.
/// Regenerated with each router (see below).
var _branchKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

/// Takes the user to the top of the News feed (first tab), closing any
/// story they had open there. Used after preferences change, so they see the
/// re-filtered feed straight away.
void goToNewsHome(GoRouter router) {
  _branchKeys[0].currentState?.popUntil((route) => route.isFirst);
  router.go('/');
}

/// Last visited location, so a rebuilt router reopens the same tab.
String _lastLocation = '/';

final goRouterProvider = Provider<GoRouter>((ref) {
  // The router is NOT rebuilt on every auth state change — that would recreate
  // the login screen mid-sign-in and wipe its loading state. Instead the
  // redirect re-runs only when the user actually signs in or out.
  final authChanges = ValueNotifier<bool>(ref.read(authStateProvider).isLoggedIn);
  ref.listen(authStateProvider, (_, next) => authChanges.value = next.isLoggedIn);
  ref.onDispose(authChanges.dispose);

  // A theme change builds a fresh router (and so a fresh widget tree) so every
  // screen repaints with the new palette; it reopens the current tab.
  ref.watch(effectiveBrightnessProvider);
  _branchKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  late final GoRouter router;
  router = GoRouter(
    initialLocation: _lastLocation,
    refreshListenable: authChanges,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).isLoggedIn;
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Indexed stack keeps each tab alive: switching tabs preserves scroll
      // position, filters and any open detail page.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(navigatorKey: _branchKeys[0], routes: [
            GoRoute(path: '/', builder: (context, state) => const NewsScreen()),
          ]),
          StatefulShellBranch(navigatorKey: _branchKeys[1], routes: [
            GoRoute(path: '/social', builder: (context, state) => const SocialScreen()),
          ]),
          StatefulShellBranch(navigatorKey: _branchKeys[2], routes: [
            GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
          ]),
          StatefulShellBranch(navigatorKey: _branchKeys[3], routes: [
            GoRoute(path: '/watchlist', builder: (context, state) => const WatchlistScreen()),
          ]),
          StatefulShellBranch(navigatorKey: _branchKeys[4], routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
  router.routerDelegate.addListener(() {
    final loc = router.routerDelegate.currentConfiguration.uri.toString();
    if (loc.isNotEmpty) _lastLocation = loc;
  });
  return router;
});

class FalconIntelApp extends ConsumerStatefulWidget {
  const FalconIntelApp({super.key});

  @override
  ConsumerState<FalconIntelApp> createState() => _FalconIntelAppState();
}

class _FalconIntelAppState extends ConsumerState<FalconIntelApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    ref.read(platformBrightnessProvider.notifier).state =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  Widget build(BuildContext context) {
    // Palette must be switched before the router (and its screens) rebuild.
    AppTheme.use(ref.watch(effectiveBrightnessProvider));
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Falcon Intel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion(value: AppTheme.overlayStyle, child: child!),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    // Right after a password sign-in the login screen leaves a fingerprint
    // offer for us; show it once the main screen is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) presentBiometricOffer(context, ref);
    });
  }

  static const _destinations = [
    (icon: Icons.newspaper_outlined, selectedIcon: Icons.newspaper_rounded, label: 'News'),
    (icon: Icons.forum_outlined, selectedIcon: Icons.forum_rounded, label: 'Social'),
    (icon: Icons.notifications_none_rounded, selectedIcon: Icons.notifications_rounded, label: 'Alerts'),
    (icon: Icons.visibility_outlined, selectedIcon: Icons.visibility_rounded, label: 'Watchlist'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Settings'),
  ];

  static const _alertsIndex = 2;

  void _onSelect(int index) {
    if (index == navigationShell.currentIndex) {
      // Tapping the active tab again returns to the top-level list.
      _branchKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
    navigationShell.goBranch(index);
    // Keep the alerts badge fresh as the user moves around.
    ref.invalidate(navAlertCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final alertCount = ref.watch(navAlertCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelect,
          destinations: [
            for (var i = 0; i < _destinations.length; i++)
              NavigationDestination(
                icon: _withBadge(Icon(_destinations[i].icon), i == _alertsIndex ? alertCount : 0),
                selectedIcon: _withBadge(Icon(_destinations[i].selectedIcon), i == _alertsIndex ? alertCount : 0),
                label: _destinations[i].label,
                tooltip: i == _alertsIndex && alertCount > 0
                    ? '${_destinations[i].label} ($alertCount unchecked)'
                    : _destinations[i].label,
              ),
          ],
        ),
      ),
    );
  }

  Widget _withBadge(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      backgroundColor: AppTheme.dangerFill,
      child: icon,
    );
  }
}
