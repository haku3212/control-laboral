import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/profile_provider.dart';
import '../../../shared/widgets/section_card.dart';
import '../data/operator_entries_repository.dart';

class OperatorHomeScreen extends ConsumerWidget {
  const OperatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final entries = ref.watch(operatorEntriesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Hola, ${profile?.fullName ?? 'operario'}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Registra tu trabajo diario desde aqui.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go('/operator/new'),
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Registrar trabajo'),
        ),
        const SizedBox(height: 16),
        entries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => SectionCard(child: Text('Error: $error')),
          data: (items) => LayoutBuilder(
            builder: (context, constraints) {
              final pending = items.where((e) => e.status == 'draft').length;
              final confirmed =
                  items.where((e) => e.status == 'confirmed').length;
              return GridView.count(
                crossAxisCount: constraints.maxWidth > 520 ? 3 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.45,
                children: [
                  _StatCard(
                      'Ultimos registros', '${items.length}', Icons.history),
                  _StatCard('Pendientes', '$pending', Icons.pending_actions),
                  _StatCard(
                      'Confirmados', '$confirmed', Icons.check_circle_outline),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          child: Text(
            'El operario puede agregar trabajadores y trabajos, pero no ve tarifas, subtotales ni pagos. El admin revisa y aprueba los registros.',
          ),
        ),
      ],
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
