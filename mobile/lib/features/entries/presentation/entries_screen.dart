import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/work_entry.dart';
import '../data/work_entries_repository.dart';

class EntriesScreen extends ConsumerWidget {
  const EntriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(workEntriesProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return AsyncValueView(
      value: entries,
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Sin registros',
            message: 'Los registros enviados por el operario apareceran aqui.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workEntriesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.employeeName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Chip(label: Text(_statusLabel(item.status))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(item.workDate)} - ${item.workTypeName} - ${_formatQuantity(item.quantity)} ${item.unit}',
                      ),
                      if (item.note != null) ...[
                        const SizedBox(height: 4),
                        Text(item.note!),
                      ],
                      if (item.status == 'draft' ||
                          item.status == 'pending') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _reject(context, ref, item.id),
                                icon: const Icon(Icons.block),
                                label: const Text('Rechazar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _setStatus(ref, item.id, 'confirmed'),
                                icon: const Icon(Icons.check),
                                label: const Text('Aprobar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (item.status != 'void') ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _editEntry(context, ref, item),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar cantidad o nota'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _setStatus(WidgetRef ref, String id, String status) async {
    await ref.read(workEntriesRepositoryProvider).updateStatus(id, status);
    ref.invalidate(workEntriesProvider);
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Observacion'),
          minLines: 2,
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await ref
        .read(workEntriesRepositoryProvider)
        .updateStatus(id, 'rejected', reason: reason);
    ref.invalidate(workEntriesProvider);
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    WorkEntry item,
  ) async {
    final quantityController = TextEditingController(
      text: _formatQuantity(item.quantity),
    );
    final noteController = TextEditingController(text: item.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar registro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cantidad u horas'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Nota'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final quantity =
        double.tryParse(quantityController.text.replaceAll(',', '.'));
    final note = noteController.text;
    quantityController.dispose();
    noteController.dispose();
    if (saved != true || quantity == null || quantity <= 0) return;

    await ref.read(workEntriesRepositoryProvider).updateDetails(
          id: item.id,
          quantity: quantity,
          note: note,
        );
    ref.invalidate(workEntriesProvider);
  }

  String _statusLabel(String status) {
    return switch (status) {
      'draft' => 'Pendiente',
      'pending' => 'Pendiente',
      'confirmed' => 'Confirmado',
      'corrected' => 'Corregido',
      'rejected' => 'Rechazado',
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
