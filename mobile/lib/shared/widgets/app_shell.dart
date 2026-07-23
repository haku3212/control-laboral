import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/profile_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _adminDestinations = [
    _Destination('/dashboard', Icons.home_outlined, Icons.home, 'Inicio'),
    _Destination('/entries', Icons.assignment_outlined, Icons.assignment, 'Registros'),
    _Destination('/payroll', Icons.payments_outlined, Icons.payments, 'Pagos'),
    _Destination('/reports', Icons.bar_chart_outlined, Icons.bar_chart, 'Reportes'),
    _Destination('/more', Icons.more_horiz, Icons.more, 'Mas'),
  ];

  static const _operatorDestinations = [
    _Destination('/operator', Icons.home_outlined, Icons.home, 'Inicio'),
    _Destination('/operator/new', Icons.add_task_outlined, Icons.add_task, 'Registrar'),
    _Destination('/operator/entries', Icons.history_outlined, Icons.history, 'Mis registros'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final destinations =
        profile?.isOperator == true ? _operatorDestinations : _adminDestinations;
    final currentIndex = destinations.indexWhere((d) => d.path == location);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.isOperator == true ? 'Mi jornada' : 'Control Laboral'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (index) => context.go(destinations[index].path),
        destinations: [
          for (final item in destinations)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.path, this.icon, this.selectedIcon, this.label);

  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
