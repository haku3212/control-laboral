import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/app_data_refresh.dart';
import '../../../shared/widgets/support_footer.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: const Text('Trabajadores'),
            subtitle: const Text('Crear, editar y activar trabajadores'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              refreshEmployeeData(ref);
              context.go('/employees');
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.work_outline),
            title: const Text('Tipos de trabajo'),
            subtitle: const Text('Unidades, categorías y estado'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              refreshWorkTypeData(ref);
              context.go('/work-types');
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.price_change_outlined),
            title: const Text('Tarifas'),
            subtitle: const Text('Tarifas generales y especiales'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              refreshRateData(ref);
              context.go('/rates');
            },
          ),
        ),
        const SupportFooter(),
      ],
    );
  }
}
