import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/work_entry.dart';
import '../data/work_entries_repository.dart';

class EntriesScreen extends ConsumerStatefulWidget {
  const EntriesScreen({super.key});

  @override
  ConsumerState<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends ConsumerState<EntriesScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(workEntriesByDateProvider(_selectedDate));
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return AsyncValueView(
      value: entries,
      data: (items) {
        final groups = _groupByEmployee(items);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(workEntriesByDateProvider(_selectedDate));
            await ref.read(workEntriesByDateProvider(_selectedDate).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _DateHeader(
                date: dateFormat.format(_selectedDate),
                onPrevious: () => _moveDate(-1),
                onNext: () => _moveDate(1),
                onPick: _pickDate,
                onToday: _setToday,
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Sin registros',
                  message: 'No hay registros para la fecha seleccionada.',
                )
              else
                for (final group in groups) ...[
                  _EmployeeEntriesGroup(
                    group: group,
                    dateFormat: dateFormat,
                    formatQuantity: _formatQuantity,
                    onApproveGroup: () => _setGroupStatus(
                      context,
                      ref,
                      group.pendingItems.map((item) => item.id).toList(),
                      'confirmed',
                    ),
                    onApprove: (item) =>
                        _setStatus(context, ref, item.id, 'confirmed'),
                    onReject: (item) => _reject(context, ref, item.id),
                    onEdit: (item) => _editEntry(context, ref, item),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }

  List<_EmployeeEntryGroupData> _groupByEmployee(List<WorkEntry> items) {
    final grouped = <String, List<WorkEntry>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.employeeCode, () => []).add(item);
    }

    final groups = [
      for (final entry in grouped.entries)
        _EmployeeEntryGroupData(
          employeeCode: entry.value.first.employeeCode,
          employeeName: entry.value.first.employeeName,
          items: entry.value,
        ),
    ];

    groups.sort((a, b) => _compareEmployeeCode(a.employeeCode, b.employeeCode));
    return groups;
  }

  void _moveDate(int days) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + days,
      );
    });
  }

  void _setToday() {
    setState(() => _selectedDate = DateTime.now());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _selectedDate,
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String id,
    String status,
  ) async {
    try {
      await ref.read(workEntriesRepositoryProvider).updateStatus(id, status);
      ref.invalidate(workEntriesByDateProvider(_selectedDate));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro aprobado correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el registro: $error')),
        );
      }
    }
  }

  Future<void> _setGroupStatus(
    BuildContext context,
    WidgetRef ref,
    List<String> ids,
    String status,
  ) async {
    if (ids.isEmpty) return;
    try {
      await ref.read(workEntriesRepositoryProvider).updateStatuses(ids, status);
      ref.invalidate(workEntriesByDateProvider(_selectedDate));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registros aprobados correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo aprobar el grupo: $error')),
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

    if (reason == null || reason.trim().isEmpty) return;

    try {
      await ref.read(workEntriesRepositoryProvider).updateStatus(
            id,
            'rejected',
            reason: reason.trim(),
          );
      ref.invalidate(workEntriesByDateProvider(_selectedDate));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro rechazado correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo rechazar el registro: $error')),
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

    if (result == null) return;

    try {
      await ref.read(workEntriesRepositoryProvider).updateDetails(
            id: item.id,
            quantity: result.quantity,
            note: result.note,
          );
      ref.invalidate(workEntriesByDateProvider(_selectedDate));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro actualizado correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo editar el registro: $error')),
        );
      }
    }
  }

  String _formatQuantity(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  final String date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Dia anterior',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(date),
                  ),
                ),
                IconButton(
                  tooltip: 'Dia siguiente',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onToday,
              icon: const Icon(Icons.today_outlined),
              label: const Text('Ver hoy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeEntryGroupData {
  const _EmployeeEntryGroupData({
    required this.employeeCode,
    required this.employeeName,
    required this.items,
  });

  final String employeeCode;
  final String employeeName;
  final List<WorkEntry> items;

  List<WorkEntry> get pendingItems => items
      .where((item) => item.status == 'draft' || item.status == 'pending')
      .toList();
}

class _EmployeeEntriesGroup extends StatelessWidget {
  const _EmployeeEntriesGroup({
    required this.group,
    required this.dateFormat,
    required this.formatQuantity,
    required this.onApproveGroup,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
  });

  final _EmployeeEntryGroupData group;
  final DateFormat dateFormat;
  final String Function(double value) formatQuantity;
  final VoidCallback onApproveGroup;
  final void Function(WorkEntry item) onApprove;
  final void Function(WorkEntry item) onReject;
  final void Function(WorkEntry item) onEdit;

  @override
  Widget build(BuildContext context) {
    final totalQuantity =
        group.items.fold(0.0, (sum, item) => sum + item.quantity);
    final pendingCount = group.pendingItems.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initials(group.employeeName))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.employeeCode} - ${group.employeeName}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${group.items.length} registros - '
                        'Total: ${formatQuantity(totalQuantity)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (pendingCount > 0)
                  Chip(
                    label: Text('$pendingCount pendientes'),
                    avatar: const Icon(Icons.pending_actions, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (pendingCount > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onApproveGroup,
                  icon: const Icon(Icons.done_all_outlined),
                  label: Text('Aprobar $pendingCount registros juntos'),
                ),
              ),
            ],
            const Divider(height: 22),
            for (final item in group.items) ...[
              _EntryLine(
                item: item,
                date: dateFormat.format(item.workDate),
                quantity: formatQuantity(item.quantity),
                onApprove: item.status == 'draft' || item.status == 'pending'
                    ? () => onApprove(item)
                    : null,
                onReject: item.status == 'draft' || item.status == 'pending'
                    ? () => onReject(item)
                    : null,
                onEdit: item.status == 'void' ? null : () => onEdit(item),
              ),
              if (item != group.items.last) const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _EntryLine extends StatelessWidget {
  const _EntryLine({
    required this.item,
    required this.date,
    required this.quantity,
    this.onApprove,
    this.onReject,
    this.onEdit,
  });

  final WorkEntry item;
  final String date;
  final String quantity;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.workTypeName,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _StatusChip(status: item.status),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoPill(icon: Icons.calendar_today_outlined, text: date),
            _InfoPill(
              icon: Icons.numbers,
              text: '$quantity ${_unitLabel(item.unit)}',
            ),
          ],
        ),
        if (item.note != null && item.note!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(item.note!),
        ],
        if (onApprove != null || onReject != null || onEdit != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (onEdit != null)
                IconButton.filledTonal(
                  tooltip: 'Editar',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (onEdit != null) const SizedBox(width: 8),
              if (onReject != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Rechazar'),
                  ),
                ),
              if (onReject != null && onApprove != null)
                const SizedBox(width: 8),
              if (onApprove != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aprobar'),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _unitLabel(String value) {
    return switch (value) {
      'hour' => 'h',
      'day' => 'dia',
      'unit' => 'unid.',
      'service' => 'serv.',
      'bag' => 'bolsa',
      'bucket' => 'tacho',
      'tray' => 'bandeja',
      _ => value,
    };
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (status) {
      'confirmed' => (
          'Confirmado',
          colorScheme.primaryContainer,
          Icons.check_circle_outline,
        ),
      'corrected' => (
          'Corregido',
          colorScheme.tertiaryContainer,
          Icons.edit_note_outlined,
        ),
      'rejected' => (
          'Rechazado',
          colorScheme.errorContainer,
          Icons.block,
        ),
      'void' => (
          'Anulado',
          colorScheme.surfaceContainerHighest,
          Icons.cancel_outlined,
        ),
      _ => (
          'Pendiente',
          colorScheme.secondaryContainer,
          Icons.pending_actions,
        ),
    };

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: color,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
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
        const SnackBar(content: Text('Ingresa el motivo del rechazo.')),
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
        decoration: const InputDecoration(labelText: 'Observacion'),
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
    _quantityController = TextEditingController(text: widget.initialQuantity);
    _noteController = TextEditingController(text: widget.initialNote);
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
        const SnackBar(content: Text('Ingresa una cantidad u horas valida.')),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cantidad u horas'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Nota'),
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

int _compareEmployeeCode(String a, String b) {
  final numberA = int.tryParse(a.trim());
  final numberB = int.tryParse(b.trim());
  if (numberA != null && numberB != null && numberA != numberB) {
    return numberA.compareTo(numberB);
  }
  return a.compareTo(b);
}
