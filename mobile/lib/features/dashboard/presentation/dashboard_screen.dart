import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_providers.dart';

final dashboardStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw StateError('Sesión no iniciada.');
  final profile = await client
      .from('profiles')
      .select('empresa_id')
      .eq('id', userId)
      .single();
  final empresaId = profile['empresa_id'] as String?;
  if (empresaId == null || empresaId.isEmpty) {
    throw StateError('Tu usuario no tiene empresa asignada.');
  }

  final employees = await client
      .from('employees')
      .select('id')
      .eq('empresa_id', empresaId)
      .eq('active', true);
  final entriesToday = await client
      .from('work_entries')
      .select('id')
      .eq('empresa_id', empresaId)
      .eq('work_date', today);
  final workTypes = await client
      .from('work_types')
      .select('id')
      .eq('empresa_id', empresaId)
      .eq('active', true);
  final pending = await client
      .from('work_entries')
      .select('id')
      .eq('empresa_id', empresaId)
      .eq('status', 'draft');

  return {
    'employees': employees.length,
    'entriesToday': entriesToday.length,
    'workTypes': workTypes.length,
    'pending': pending.length,
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final format = DateFormat('dd/MM/yyyy', 'es_BO');

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardStatsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _DashboardHeader(
            title: 'Panel gerente',
            subtitle:
                '${format.format(weekStart)} al ${format.format(weekEnd)}',
            onRefresh: () => ref.invalidate(dashboardStatsProvider),
          ),
          const SizedBox(height: 12),
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No se pudo cargar el panel: $error'),
              ),
            ),
            data: (data) => LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 760 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: constraints.maxWidth > 760 ? 2.25 : 1.75,
                  children: [
                    _StatCard(
                      label: 'Trabajadores',
                      value: '${data['employees']}',
                      icon: Icons.groups_outlined,
                    ),
                    _StatCard(
                      label: 'Hoy',
                      value: '${data['entriesToday']}',
                      icon: Icons.today_outlined,
                    ),
                    _StatCard(
                      label: 'Trabajos',
                      value: '${data['workTypes']}',
                      icon: Icons.work_outline,
                    ),
                    _StatCard(
                      label: 'Pendientes',
                      value: '${data['pending']}',
                      icon: Icons.pending_actions,
                      warning: (data['pending'] ?? 0) > 0,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Acciones rápidas',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.fact_check_outlined,
            title: 'Revisar jornadas',
            subtitle: 'Aprobar, corregir o rechazar registros',
            onTap: () => context.go('/entries'),
          ),
          _ActionTile(
            icon: Icons.payments_outlined,
            title: 'Pagos estimados',
            subtitle: 'Ver faltantes, ajustes y pagos',
            onTap: () => context.go('/payroll'),
          ),
          _ActionTile(
            icon: Icons.table_view_outlined,
            title: 'Reportes',
            subtitle: 'Exportar PDF y planillas',
            onTap: () => context.go('/reports'),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Actualizar',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = warning ? colorScheme.errorContainer : colorScheme.surface;

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
