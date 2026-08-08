import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/operator_entry.dart';
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
        final groups = _groupEntries(items);
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.history_outlined,
            title: 'Sin registros',
            message: 'Tus registros enviados aparecerán aquí.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(operatorEntriesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _OperatorEntriesSummary(items: items),
              const SizedBox(height: 12),
              for (final group in groups) ...[
                _OperatorEntryGroupCard(
                  group: group,
                  date: dateFormat.format(group.workDate),
                  formatQuantity: _formatQuantity,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatQuantity(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
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
    final today = DateTime.now();
    final todayCount = items.where((item) {
      return item.workDate.year == today.year &&
          item.workDate.month == today.month &&
          item.workDate.day == today.day;
    }).length;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de tus envíos',
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
                _SummaryPill(label: 'Hoy', value: '$todayCount'),
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
    required this.formatQuantity,
  });

  final _OperatorEntryGroup group;
  final String date;
  final String Function(double value) formatQuantity;

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
                    text: '${group.items.length} lineas'),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in group.items) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.workTypeName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '${formatQuantity(item.quantity)} ${_unitLabel(item.workTypeUnit)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (item.note != null && item.note!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(item.note!),
                ),
              if (item != group.items.last) const Divider(height: 16),
            ],
          ],
        ),
      ),
    );
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
