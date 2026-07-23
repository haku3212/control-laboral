import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/role_gate_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/employees/presentation/employees_screen.dart';
import '../features/entries/presentation/entries_screen.dart';
import '../features/operator/presentation/operator_entries_screen.dart';
import '../features/operator/presentation/operator_home_screen.dart';
import '../features/operator/presentation/operator_new_entry_screen.dart';
import '../features/payroll/presentation/payroll_screen.dart';
import '../features/rates/presentation/rates_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/work_types/presentation/work_types_screen.dart';
import '../shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final loggingIn = state.matchedLocation == '/login';
    if (!loggedIn) return loggingIn ? null : '/login';
    if (loggingIn) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/home', builder: (_, __) => const RoleGateScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/entries', builder: (_, __) => const EntriesScreen()),
        GoRoute(path: '/payroll', builder: (_, __) => const PayrollScreen()),
        GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
        GoRoute(path: '/more', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/employees', builder: (_, __) => const EmployeesScreen()),
        GoRoute(path: '/work-types', builder: (_, __) => const WorkTypesScreen()),
        GoRoute(path: '/rates', builder: (_, __) => const RatesScreen()),
        GoRoute(path: '/operator', builder: (_, __) => const OperatorHomeScreen()),
        GoRoute(path: '/operator/new', builder: (_, __) => const OperatorNewEntryScreen()),
        GoRoute(path: '/operator/entries', builder: (_, __) => const OperatorEntriesScreen()),
      ],
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
