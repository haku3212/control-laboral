import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/utils/app_data_refresh.dart';
import '../data/work_entry.dart';
import '../data/work_entries_repository.dart';

class EntriesScreen extends ConsumerStatefulWidget {
  const EntriesScreen({super.key});

  @override
  ConsumerState<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends ConsumerState<EntriesScreen> {
  late DateTime _weekStart;

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');
    final entries = ref.watch(
      workEntriesByRangeProvider(
        (startDate: _weekStart, endDate: _weekEnd),
      ),
    );
    final rangeText =
        '${dateFormat.format(_weekStart)} - ${dateFormat.format(_weekEnd)}';

    return AsyncValueView(
      value: entries,
      data: (items) {
        final groups = _groupByEmployee(items);

        return RefreshIndicator(
          onRefresh: () async {
            refreshEntryData(ref);
            await ref.read(
              workEntriesByRangeProvider(
                (startDate: _weekStart, endDate: _weekEnd),
              ).future,
            );
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _WeekHeader(
                rangeText: rangeText,
                onPrevious: () => _moveWeek(-1),
                onNext: () => _moveWeek(1),
                onPick: _pickWeek,
                onCurrent: _setCurrentWeek,
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Sin registros',
                  message: 'No hay registros para la semana seleccionada.',
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

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  void _moveWeek(int weeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: weeks * 7));
    });
  }

  void _setCurrentWeek() {
    setState(() => _weekStart = _startOfWeek(DateTime.now()));
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _weekStart,
    );
    if (picked == null) return;
    setState(() => _weekStart = _startOfWeek(picked));
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
      refreshEntryData(ref);

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

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.rangeText,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onCurrent,
  });

  final String rangeText;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onCurrent;

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
                    label: Text(rangeText),
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
              onPressed: onCurrent,
              icon: const Icon(Icons.today_outlined),
              label: const Text('Ver semana actual'),
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

  List<_EmployeeDayGroup> get dayGroups {
    final grouped = <String, List<WorkEntry>>{};
    for (final item in items) {
      final day = DateTime(
        item.workDate.year,
        item.workDate.month,
        item.workDate.day,
      );
      grouped.putIfAbsent(day.toIso8601String(), () => []).add(item);
    }

    final groups = [
      for (final entry in grouped.entries)
        _EmployeeDayGroup(
          date: DateTime.parse(entry.key),
          items: entry.value,
        ),
    ];
    groups.sort((a, b) => a.date.compareTo(b.date));
    return groups;
  }
}

class _EmployeeDayGroup {
  const _EmployeeDayGroup({
    required this.date,
    required this.items,
  });

  final DateTime date;
  final List<WorkEntry> items;
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
            for (final dayGroup in group.dayGroups) ...[
              const Divider(height: 22),
              _DayBlock(
                dayGroup: dayGroup,
                dateFormat: dateFormat,
                formatQuantity: formatQuantity,
              ),
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

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    required this.dayGroup,
    required this.dateFormat,
    required this.formatQuantity,
  });

  final _EmployeeDayGroup dayGroup;
  final DateFormat dateFormat;
  final String Function(double value) formatQuantity;

  @override
  Widget build(BuildContext context) {
    final title = '${_weekdayLabel(dayGroup.date)} '
        '${dateFormat.format(dayGroup.date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        for (final item in dayGroup.items) ...[
          _EntryLine(
            item: item,
            quantity: _quantityText(item.quantity, item.unit),
          ),
          if (item != dayGroup.items.last) const Divider(height: 18),
        ],
      ],
    );
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
      'batch' => 'batch',
      _ => value,
    };
  }

  String _weekdayLabel(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => 'Lunes',
      DateTime.tuesday => 'Martes',
      DateTime.wednesday => 'Miercoles',
      DateTime.thursday => 'Jueves',
      DateTime.friday => 'Viernes',
      DateTime.saturday => 'Sabado',
      DateTime.sunday => 'Domingo',
      _ => '',
    };
  }
}

class _EntryLine extends StatelessWidget {
  const _EntryLine({
    required this.item,
    required this.quantity,
  });

  final WorkEntry item;
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
