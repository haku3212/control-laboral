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
      .eq('status', 'pending');

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
            title: 'Hola, gerente',
            subtitle:
                'Semana del ${format.format(weekStart)} al ${format.format(weekEnd)}',
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
            title: 'Revisar registros',
            subtitle: 'Aprobar o corregir lo enviado por el encargado',
            onTap: () => context.go('/entries'),
          ),
          _ActionTile(
            icon: Icons.payments_outlined,
            title: 'Ver pagos',
            subtitle: 'Totales por trabajador y pagos por cancelar',
            onTap: () => context.go('/payroll'),
          ),
          _ActionTile(
            icon: Icons.table_view_outlined,
            title: 'Planillas y comprobantes',
            subtitle: 'PDF, Excel y resumen para cada trabajador',
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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
    final bg = warning ? colorScheme.errorContainer : colorScheme.surface;
    final fg = warning ? colorScheme.onErrorContainer : colorScheme.primary;

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: fg, size: 20),
                ),
                const Spacer(),
                if (warning)
                  Icon(
                    Icons.priority_high_rounded,
                    color: colorScheme.onErrorContainer,
                    size: 20,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
