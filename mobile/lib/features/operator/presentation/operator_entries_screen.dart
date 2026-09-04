import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/app_data_refresh.dart';
import '../data/operator_entry.dart';
import '../data/operator_entries_repository.dart';

class OperatorEntriesScreen extends ConsumerStatefulWidget {
  const OperatorEntriesScreen({super.key});

  @override
  ConsumerState<OperatorEntriesScreen> createState() =>
      _OperatorEntriesScreenState();
}

class _OperatorEntriesScreenState extends ConsumerState<OperatorEntriesScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(operatorEntriesByDateProvider(_selectedDate));
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return AsyncValueView(
      value: entries,
      data: (items) {
        final groups = _groupEntries(items);

        return RefreshIndicator(
          onRefresh: () async => refreshEntryData(ref, date: _selectedDate),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _DateHeader(
                date: dateFormat.format(_selectedDate),
                onPrevious: _selectedDate.isAfter(_oldestVisibleDate)
                    ? () => _moveDate(-1)
                    : null,
                onNext: !_isSameDay(_selectedDate, DateTime.now())
                    ? () => _moveDate(1)
                    : null,
                onPick: _pickDate,
                onToday: _setToday,
              ),
              const SizedBox(height: 12),
              _OperatorEntriesSummary(items: items),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.history_outlined,
                  title: 'Sin registros ese dia',
                  message: 'Tus registros enviados apareceran aqui por fecha.',
                )
              else
                for (final group in groups) ...[
                  _OperatorEntryGroupCard(
                    group: group,
                    date: dateFormat.format(group.workDate),
                    onEdit: _editEntry,
                    onDelete: _deleteEntry,
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }

  DateTime get _oldestVisibleDate {
    final cutoff = DateTime.now().subtract(const Duration(days: 92));
    return DateTime(cutoff.year, cutoff.month, cutoff.day);
  }

  void _moveDate(int days) {
    setState(() {
      final next = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + days,
      );
      if (next.isBefore(_oldestVisibleDate)) {
        _selectedDate = _oldestVisibleDate;
      } else if (next.isAfter(DateTime.now())) {
        _selectedDate = DateTime.now();
      } else {
        _selectedDate = next;
      }
    });
  }

  void _setToday() {
    setState(() => _selectedDate = DateTime.now());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _oldestVisibleDate,
      lastDate: DateTime.now(),
      initialDate: _selectedDate,
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<_OperatorEntryGroup> _groupEntries(List<OperatorEntry> items) {
    final grouped = <String, List<OperatorEntry>>{};
    for (final item in items) {
      final day =
          DateTime(item.workDate.year, item.workDate.month, item.workDate.day);
      final key =
          '${item.employeeName}|${day.toIso8601String()}|${item.status}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final groups = [
      for (final entry in grouped.entries)
        _OperatorEntryGroup(
          employeeName: entry.value.first.employeeName,
          workDate: entry.value.first.workDate,
          status: entry.value.first.status,
          items: entry.value,
        ),
    ];
    groups.sort((a, b) => b.workDate.compareTo(a.workDate));
    return groups;
  }

  Future<void> _editEntry(OperatorEntry entry) async {
    if (!_canModify(entry)) {
      _showMessage(
        'Este registro ya fue revisado. Pide al gerente que lo corrija.',
      );
      return;
    }

    final result = await showDialog<_EditEntryResult>(
      context: context,
      builder: (_) => _EditEntryDialog(entry: entry),
    );
    if (result == null) return;

    try {
      await ref.read(operatorEntriesRepositoryProvider).updatePendingEntry(
            id: entry.id,
            quantity: result.quantity,
            note: result.note,
          );
      refreshEntryData(ref, date: _selectedDate);
      _showMessage('Registro actualizado correctamente.');
    } catch (error) {
      _showMessage(_friendlyError('No se pudo editar', error));
    }
  }

  Future<void> _deleteEntry(OperatorEntry entry) async {
    if (!_canModify(entry)) {
      _showMessage(
        'Este registro ya fue revisado. Pide al gerente que lo corrija.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteEntryDialog(entry: entry),
    );
    if (confirmed != true) return;

    try {
      await ref.read(operatorEntriesRepositoryProvider).deletePendingEntry(
            entry.id,
          );
      refreshEntryData(ref, date: _selectedDate);
      _showMessage('Registro eliminado correctamente.');
    } catch (error) {
      _showMessage(_friendlyError('No se pudo eliminar', error));
    }
  }

  bool _canModify(OperatorEntry entry) {
    return entry.status == 'pending' || entry.status == 'draft';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _friendlyError(String action, Object error) {
    final text = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
    return '$action: $text';
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
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
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
            Text(
              'Se muestra solo un dia. Historial visible: ultimos 3 meses.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _OperatorEntryGroup {
  const _OperatorEntryGroup({
    required this.employeeName,
    required this.workDate,
    required this.status,
    required this.items,
  });

  final String employeeName;
  final DateTime workDate;
  final String status;
  final List<OperatorEntry> items;
}

class _OperatorEntriesSummary extends StatelessWidget {
  const _OperatorEntriesSummary({required this.items});

  final List<OperatorEntry> items;

  @override
  Widget build(BuildContext context) {
    final pending = items.where((item) => item.status == 'pending').length;
    final confirmed = items.where((item) => item.status == 'confirmed').length;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen del dia',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryPill(label: 'Lineas', value: '${items.length}'),
                _SummaryPill(label: 'Pendientes', value: '$pending'),
                _SummaryPill(label: 'Confirmados', value: '$confirmed'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _OperatorEntryGroupCard extends StatelessWidget {
  const _OperatorEntryGroupCard({
    required this.group,
    required this.date,
    required this.onEdit,
    required this.onDelete,
  });

  final _OperatorEntryGroup group;
  final String date;
  final ValueChanged<OperatorEntry> onEdit;
  final ValueChanged<OperatorEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    _workIcon(group.items.first.workTypeUnit),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.employeeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${group.items.length} trabajos enviados',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Flexible(child: _StatusChip(status: group.status)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(icon: Icons.calendar_today_outlined, text: date),
                _InfoPill(
                  icon: Icons.format_list_bulleted,
                  text: '${group.items.length} lineas',
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in group.items) ...[
              _OperatorEntryLine(
                item: item,
                quantity: _quantityText(item.quantity, item.workTypeUnit),
                onEdit: () => onEdit(item),
                onDelete: () => onDelete(item),
              ),
              if (item != group.items.last) const Divider(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  String _quantityText(double quantity, String unit) {
    if (unit == 'hour') return _formatHours(quantity);
    final value = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    return '$value ${_unitLabel(unit)}';
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '$h h';
    return '$h h ${minutes.toString().padLeft(2, '0')} min';
  }

  IconData _workIcon(String unit) {
    return switch (unit) {
      'hour' => Icons.schedule_outlined,
      'day' => Icons.calendar_today_outlined,
      'bag' => Icons.shopping_bag_outlined,
      'bucket' => Icons.inventory_2_outlined,
      'tray' => Icons.table_bar_outlined,
      _ => Icons.assignment_outlined,
    };
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

class _OperatorEntryLine extends StatelessWidget {
  const _OperatorEntryLine({
    required this.item,
    required this.quantity,
    required this.onEdit,
    required this.onDelete,
  });

  final OperatorEntry item;
  final String quantity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  bool get canModify => item.status == 'pending' || item.status == 'draft';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.workTypeName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                quantity,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (item.note != null && item.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.note!),
          ],
          const SizedBox(height: 10),
          if (canModify)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              'Ya fue revisado por gerente.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _EditEntryResult {
  const _EditEntryResult({
    required this.quantity,
    required this.note,
  });

  final double quantity;
  final String? note;
}

class _EditEntryDialog extends StatefulWidget {
  const _EditEntryDialog({required this.entry});

  final OperatorEntry entry;

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
      text: _formatNumber(widget.entry.quantity),
    );
    _noteController = TextEditingController(text: widget.entry.note ?? '');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una cantidad mayor a cero.')),
      );
      return;
    }

    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      _EditEntryResult(
        quantity: quantity,
        note: note.isEmpty ? null : note,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entry.workTypeName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              decoration: InputDecoration(
                labelText: 'Cantidad',
                suffixText: _unitLabel(widget.entry.workTypeUnit),
              ),
              onTap: () => _quantityController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _quantityController.text.length,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nota opcional',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _DeleteEntryDialog extends StatelessWidget {
  const _DeleteEntryDialog({required this.entry});

  final OperatorEntry entry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eliminar registro'),
      content: Text(
        'Se eliminara "${entry.workTypeName}" con cantidad '
        '${_formatNumber(entry.quantity)} ${_unitLabel(entry.workTypeUnit)}. '
        'Si fue un error, despues puedes volver a registrarlo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar'),
        ),
      ],
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
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
