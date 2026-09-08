import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/providers.dart';
import '../design/components/placeholder_screen.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/trackers/presentation/trackers_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import '../navigation/app_shell.dart';
import '../navigation/destinations.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app router. Auth-aware redirect; a `StatefulShellRoute` keeps each
/// bottom-nav tab's navigation stack independent.
final routerProvider = Provider<GoRouter>((ref) {
  // Rebuilds the router's redirect whenever auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authEventProvider, (_, _) => refresh.value++);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppDestination.home.path,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(isSignedInProvider);
      final goingToAuth = state.matchedLocation == '/auth';
      if (!signedIn) return goingToAuth ? null : '/auth';
      if (goingToAuth) return AppDestination.home.path;
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppDestination.home.path,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppDestination.transactions.path,
                builder: (_, _) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppDestination.trackers.path,
                builder: (_, _) => const TrackersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppDestination.more.path,
                builder: (_, _) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      // Every "More" entry resolves to a milestone placeholder until its
      // feature phase lands.
      for (final e in kMoreEntries)
        if (e.route != '/settings')
          GoRoute(
            path: e.route,
            parentNavigatorKey: _rootKey,
            builder: (_, _) => PlaceholderScreen(
              title: e.label,
              milestone: e.phase ?? 'a later phase',
              icon: e.icon,
            ),
          ),
    ],
  );
});
