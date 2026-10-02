import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/auth/auth_service.dart';
import 'core/api/api_client.dart';
import 'core/api/endpoints.dart';
import 'features/auth/login_screen.dart';
import 'features/news/news_screen.dart';
import 'features/social/social_screen.dart';
import 'features/alerts/alerts_screen.dart';
import 'features/watchlist/watchlist_screen.dart';
import 'features/settings/settings_screen.dart';

/// Fetches alert count for the badge
final navAlertCountProvider = FutureProvider<int>((ref) async {
  try {
    final resp = await ApiClient.instance.get(Endpoints.alertsCount);
    if (resp.statusCode == 200 && resp.data is Map) {
      return (resp.data['count'] ?? 0) as int;
    }
  } catch (_) {}
  return 0;
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
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
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const NewsScreen()),
          GoRoute(path: '/social', builder: (context, state) => const SocialScreen()),
          GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
          GoRoute(path: '/watchlist', builder: (context, state) => const WatchlistScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class FalconIntelApp extends ConsumerWidget {
  const FalconIntelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Falcon Intel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _destinations = [
    (icon: Icons.newspaper, label: 'News', route: '/'),
    (icon: Icons.chat_bubble_outline, label: 'Social', route: '/social'),
    (icon: Icons.notifications_active, label: 'Alerts', route: '/alerts'),
    (icon: Icons.visibility_outlined, label: 'Watchlist', route: '/watchlist'),
    (icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _destinations.indexWhere((d) =>
        location.startsWith(d.route) && (d.route != '/' || location == '/'));

    final alertCount = ref.watch(navAlertCountProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (i) => context.go(_destinations[i].route),
        destinations: _destinations.asMap().entries.map((entry) {
          final i = entry.key;
          final d = entry.value;
          final isAlerts = d.route == '/alerts';

          // Show badge on Alerts tab
          if (isAlerts && alertCount.hasValue && alertCount.value! > 0) {
            return NavigationDestination(
              icon: Badge(
                label: Text('${alertCount.value! > 99 ? '99+' : alertCount.value}',
                    style: const TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: AppTheme.accentRed,
                textColor: Colors.white,
                child: Icon(d.icon),
              ),
              selectedIcon: Badge(
                label: Text('${alertCount.value! > 99 ? '99+' : alertCount.value}',
                    style: const TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: AppTheme.accentRed,
                textColor: Colors.white,
                child: Icon(d.icon, color: AppTheme.primaryColor),
              ),
              label: d.label,
            );
          }

          return NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.icon, color: AppTheme.primaryColor),
            label: d.label,
          );
        }).toList(),
      ),
    );
  }
}
