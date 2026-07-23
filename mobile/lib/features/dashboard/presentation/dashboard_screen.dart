import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/section_card.dart';

final dashboardStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw StateError('Sesion no iniciada.');
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
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Semana actual',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('${format.format(weekStart)} al ${format.format(weekEnd)}'),
          const SizedBox(height: 16),
          stats.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => SectionCard(child: Text('Error: $error')),
            data: (data) => LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 720 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.45,
                  children: [
                    _StatCard('Trabajadores', '${data['employees']}',
                        Icons.groups_outlined),
                    _StatCard('Jornadas hoy', '${data['entriesToday']}',
                        Icons.today_outlined),
                    _StatCard('Tipos activos', '${data['workTypes']}',
                        Icons.work_outline),
                    _StatCard('Pendientes', '${data['pending']}',
                        Icons.pending_actions),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => context.go('/entries'),
                icon: const Icon(Icons.add),
                label: const Text('Ver jornadas'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/entries'),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Revisar pendientes'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/payroll'),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Cerrar semana'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/reports'),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Generar planilla'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionCard(
            child: Text(
              'El gerente revisa jornadas, define tarifas y confirma pagos dentro de su empresa.',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label),
        ],
      ),
    );
  }
}
