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
  });

  final _EmployeeEntryGroupData group;
  final DateFormat dateFormat;
  final String Function(double value) formatQuantity;
  final VoidCallback onApproveGroup;

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
            if (pendingCount > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onApproveGroup,
                  icon: const Icon(Icons.done_all_outlined),
                  label: Text(
                    pendingCount == 1
                        ? 'Aprobar registro'
                        : 'Aprobar $pendingCount registros juntos',
                  ),
                ),
              ),
            ],
            const Divider(height: 22),
            for (final item in group.items) ...[
              _EntryLine(
                item: item,
                date: dateFormat.format(item.workDate),
                quantity: _quantityText(item.quantity, item.unit),
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

  String _quantityText(double quantity, String unit) {
    if (unit == 'hour') return _formatHours(quantity);
    return '${formatQuantity(quantity)} ${_unitLabel(unit)}';
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '$h h';
    return '$h h ${minutes.toString().padLeft(2, '0')} min';
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

class _EntryLine extends StatelessWidget {
  const _EntryLine({
    required this.item,
    required this.date,
    required this.quantity,
  });

  final WorkEntry item;
  final String date;
  final String quantity;

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
              text: quantity,
            ),
          ],
        ),
        if (item.note != null && item.note!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(item.note!),
        ],
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

int _compareEmployeeCode(String a, String b) {
  final numberA = int.tryParse(a.trim());
  final numberB = int.tryParse(b.trim());
  if (numberA != null && numberB != null && numberA != numberB) {
    return numberA.compareTo(numberB);
  }
  return a.compareTo(b);
}
