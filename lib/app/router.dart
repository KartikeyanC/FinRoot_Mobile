import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/providers.dart';
import '../design/components/placeholder_screen.dart';
import '../features/accounts/presentation/accounts_screen.dart';
import '../features/auth/application/password_recovery.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/bill_scan/presentation/bill_scan_screen.dart';
import '../features/budget/presentation/budget_screen.dart';
import '../features/goals/presentation/goals_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/investments/presentation/investments_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/net_worth/presentation/net_worth_screen.dart';
import '../features/recurring/presentation/recurring_screen.dart';
import '../features/reminders/presentation/reminders_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/trackers/presentation/tracker_detail_screen.dart';
import '../features/trackers/presentation/trackers_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import '../features/voice/presentation/voice_screen.dart';
import '../features/workspace/application/workspace_providers.dart';
import '../features/workspace/presentation/no_workspace_screen.dart';
import '../navigation/app_shell.dart';
import '../navigation/destinations.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class _Routes {
  static const auth = '/auth';
  static const resetPassword = '/reset-password';
  static const noWorkspace = '/no-workspace';
  static const settings = '/settings';
  static const accounts = '/accounts';
  static const budget = '/budget';
  static const goals = '/goals';
  static const investments = '/investments';
  static const netWorth = '/net-worth';
  static const recurring = '/recurring';
  static const reminders = '/reminders';
  static const billScan = '/bill-scan';
  static const voice = '/voice';

  /// "More" entries that have a real screen rather than a milestone placeholder.
  static const realScreens = {
    settings,
    accounts,
    budget,
    goals,
    investments,
    netWorth,
    recurring,
    reminders,
    billScan,
    voice,
  };
}

/// The app router.
///
/// Redirect precedence (M1 audit §14):
/// 1. a password-reset deep link is open → the reset screen, always;
/// 2. not signed in → the auth screen;
/// 3. signed in but no usable workspace → the "no workspace" screen;
/// 4. otherwise the app shell.
final routerProvider = Provider<GoRouter>((ref) {
  // One notifier the router listens to; every auth/workspace change bumps it.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  void bump() => refresh.value++;
  ref.listen(authEventProvider, (_, _) => bump());
  ref.listen(membershipsProvider, (_, _) => bump());
  ref.listen(passwordRecoveryProvider, (_, _) => bump());

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppDestination.home.path,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final recovering = ref.read(passwordRecoveryProvider);
      final signedIn = ref.read(isSignedInProvider);

      if (recovering) {
        return loc == _Routes.resetPassword ? null : _Routes.resetPassword;
      }
      if (loc == _Routes.resetPassword) {
        // Reached without an active recovery — send the user somewhere real.
        return signedIn ? AppDestination.home.path : _Routes.auth;
      }

      if (!signedIn) {
        return loc == _Routes.auth ? null : _Routes.auth;
      }

      // Signed in. Decide on workspace once memberships have resolved; while
      // they load, let the destination render its own loading state.
      final memberships = ref.read(membershipsProvider);
      final hasUsableWorkspace = memberships.maybeWhen(
        data: (list) => list.any((m) => m.isUsable),
        orElse: () => true, // loading — don't bounce yet
      );
      final resolvedNoWorkspace = memberships.maybeWhen(
        data: (list) => !list.any((m) => m.isUsable),
        error: (_, _) => true,
        orElse: () => false,
      );

      if (resolvedNoWorkspace) {
        return loc == _Routes.noWorkspace ? null : _Routes.noWorkspace;
      }
      if (loc == _Routes.noWorkspace && hasUsableWorkspace) {
        return AppDestination.home.path;
      }
      if (loc == _Routes.auth) return AppDestination.home.path;
      return null;
    },
    routes: [
      GoRoute(path: _Routes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: _Routes.resetPassword,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: _Routes.noWorkspace,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NoWorkspaceScreen(),
      ),
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
        path: _Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: _Routes.accounts,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/tracker/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            TrackerDetailScreen(trackerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: _Routes.budget,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const BudgetScreen(),
      ),
      GoRoute(
        path: _Routes.goals,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const GoalsScreen(),
      ),
      GoRoute(
        path: _Routes.investments,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const InvestmentsScreen(),
      ),
      GoRoute(
        path: _Routes.netWorth,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NetWorthScreen(),
      ),
      GoRoute(
        path: _Routes.recurring,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const RecurringScreen(),
      ),
      GoRoute(
        path: _Routes.reminders,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const RemindersScreen(),
      ),
      GoRoute(
        path: _Routes.billScan,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const BillScanScreen(),
      ),
      GoRoute(
        path: _Routes.voice,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const VoiceScreen(),
      ),
      // Every remaining "More" entry resolves to a milestone placeholder until
      // its feature phase lands.
      for (final e in kMoreEntries)
        if (!_Routes.realScreens.contains(e.route))
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
