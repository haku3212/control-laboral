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
            message: 'Los registros enviados por el operario aparecerán aquí.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(workEntriesProvider);
            await ref.read(workEntriesProvider.future);
          },
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
                          Chip(
                            label: Text(_statusLabel(item.status)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(item.workDate)} - '
                        '${item.workTypeName} - '
                        '${_formatQuantity(item.quantity)} ${item.unit}',
                      ),
                      if (item.note != null &&
                          item.note!.trim().isNotEmpty) ...[
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
                                onPressed: () async {
                                  await _reject(context, ref, item.id);
                                },
                                icon: const Icon(Icons.block),
                                label: const Text('Rechazar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await _setStatus(
                                    context,
                                    ref,
                                    item.id,
                                    'confirmed',
                                  );
                                },
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
                          onPressed: () async {
                            await _editEntry(context, ref, item);
                          },
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

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String id,
    String status,
  ) async {
    try {
      await ref.read(workEntriesRepositoryProvider).updateStatus(id, status);
      ref.invalidate(workEntriesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro aprobado correctamente.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar el registro: $error'),
          ),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectEntryDialog(),
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    try {
      await ref.read(workEntriesRepositoryProvider).updateStatus(
            id,
            'rejected',
            reason: reason.trim(),
          );

      ref.invalidate(workEntriesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro rechazado correctamente.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo rechazar el registro: $error'),
          ),
        );
      }
    }
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    WorkEntry item,
  ) async {
    final result = await showDialog<_EntryEditResult>(
      context: context,
      builder: (_) => _EditEntryDialog(
        initialQuantity: _formatQuantity(item.quantity),
        initialNote: item.note ?? '',
      ),
    );

    if (result == null) {
      return;
    }

    try {
      await ref.read(workEntriesRepositoryProvider).updateDetails(
            id: item.id,
            quantity: result.quantity,
            note: result.note,
          );

      ref.invalidate(workEntriesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro actualizado correctamente.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo editar el registro: $error'),
          ),
        );
      }
    }
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

class _RejectEntryDialog extends StatefulWidget {
  const _RejectEntryDialog();

  @override
  State<_RejectEntryDialog> createState() => _RejectEntryDialogState();
}

class _RejectEntryDialogState extends State<_RejectEntryDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el motivo del rechazo.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Motivo del rechazo'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Observación',
        ),
        minLines: 2,
        maxLines: 4,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}

class _EditEntryDialog extends StatefulWidget {
  const _EditEntryDialog({
    required this.initialQuantity,
    required this.initialNote,
  });

  final String initialQuantity;
  final String initialNote;

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.initialQuantity,
    );
    _noteController = TextEditingController(
      text: widget.initialNote,
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una cantidad u horas válida.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _EntryEditResult(
        quantity: quantity,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar registro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _quantityController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cantidad u horas',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Nota',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _EntryEditResult {
  const _EntryEditResult({
    required this.quantity,
    required this.note,
  });

  final double quantity;
  final String note;
}
