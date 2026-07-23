import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/operator_entries_repository.dart';

class OperatorEntriesScreen extends ConsumerWidget {
  const OperatorEntriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(operatorEntriesProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return AsyncValueView(
      value: entries,
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.history_outlined,
            title: 'Sin registros',
            message: 'Tus registros enviados apareceran aqui.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(operatorEntriesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text('${item.employeeName} - ${item.workTypeName}'),
                  subtitle: Text(
                    '${dateFormat.format(item.workDate)} - ${_formatQuantity(item.quantity)} ${item.workTypeUnit}'
                    '${item.note == null ? '' : '\n${item.note}'}',
                  ),
                  isThreeLine: item.note != null,
                  trailing: Chip(label: Text(_statusLabel(item.status))),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'draft' => 'Pendiente',
      'confirmed' => 'Confirmado',
      'corrected' => 'Corregido',
      'void' => 'Anulado',
      _ => status,
    };
  }

  String _formatQuantity(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}
