import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/utils/app_data_refresh.dart';
import '../../rates/data/rates_repository.dart';
import '../data/payroll_repository.dart';
import '../data/payroll_summary.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  late DateTime _weekStart;
  final TextEditingController _searchController = TextEditingController();
  _PayrollFilter _filter = _PayrollFilter.pending;

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
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

  void _goToCurrentWeek() {
    setState(() => _weekStart = _startOfWeek(DateTime.now()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeePayrollSummary> _visibleItems(
      List<EmployeePayrollSummary> items) {
    final query = _searchController.text.trim().toLowerCase();

    return items.where((item) {
      final matchesQuery = query.isEmpty ||
          item.employeeName.toLowerCase().contains(query) ||
          item.employeeCode.toLowerCase().contains(query);
      if (!matchesQuery) return false;

      return switch (_filter) {
        _PayrollFilter.all => true,
        _PayrollFilter.pending => !item.isPaid,
        _PayrollFilter.ready => !item.isPaid && !item.hasMissingRates,
        _PayrollFilter.missingRates => !item.isPaid && item.hasMissingRates,
        _PayrollFilter.paid => item.isPaid,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(
      payrollSummariesByRangeProvider(
        (startDate: _weekStart, endDate: _weekEnd),
      ),
    );
    final money = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ');
    final day = DateFormat('dd/MM/yyyy');
    final rangeText = '${day.format(_weekStart)} - ${day.format(_weekEnd)}';

    return AsyncValueView(
      value: summaries,
      data: (items) {
        final visibleItems = _visibleItems(items);
        final pendingItems = items.where((item) => !item.isPaid).toList();

        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => refreshPayrollData(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _WeekSelector(
                  rangeText: rangeText,
                  onPrevious: () => _moveWeek(-1),
                  onNext: () => _moveWeek(1),
                  onCurrent: _goToCurrentWeek,
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'No hay pagos cargados en esta semana. '
                    'Verifica que los registros esten confirmados.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        final gross =
            pendingItems.fold(0.0, (sum, item) => sum + item.grossPayable);
        final total =
            pendingItems.fold(0.0, (sum, item) => sum + item.totalPayable);
        final missingRates =
            pendingItems.where((item) => item.hasMissingRates).length;
        final readyToPay = pendingItems
            .where((item) => !item.hasMissingRates)
            .fold(0.0, (sum, item) => sum + item.totalPayable);

        return RefreshIndicator(
          onRefresh: () async => refreshPayrollData(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _WeekSelector(
                rangeText: rangeText,
                onPrevious: () => _moveWeek(-1),
                onNext: () => _moveWeek(1),
                onCurrent: _goToCurrentWeek,
              ),
              const SizedBox(height: 16),
              _PayrollOverview(
                gross: gross,
                total: total,
                readyToPay: readyToPay,
                missingRates: missingRates,
                workerCount: pendingItems.length,
                money: money,
                onCloseWeek: () => _closeWeek(context, ref),
              ),
              const SizedBox(height: 16),
              _PayrollSearchAndFilters(
                controller: _searchController,
                filter: _filter,
                onChanged: () => setState(() {}),
                onFilterChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 12),
              if (visibleItems.isEmpty)
                const _EmptyPayrollFilter()
              else
                for (final item in visibleItems) ...[
                  _EmployeePayrollCard(summary: item, money: money),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _closeWeek(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(payrollRepositoryProvider)
          .closeWeek(startDate: _weekStart, endDate: _weekEnd);
      refreshPayrollData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semana cerrada correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cerrar la semana: $error')),
        );
      }
    }
  }
}

enum _PayrollFilter { pending, ready, missingRates, paid, all }

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.rangeText,
    required this.onPrevious,
    required this.onNext,
    required this.onCurrent,
  });

  final String rangeText;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCurrent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Semana de pago',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: 'Semana anterior',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      rangeText,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Semana siguiente',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCurrent,
              icon: const Icon(Icons.today_outlined),
              label: const Text('Ir a esta semana'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 150,
      child: Card(
        color: warning ? colorScheme.errorContainer : colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip({required this.isPaid});

  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(
        isPaid ? Icons.check_circle_outline : Icons.pending_actions,
        size: 18,
      ),
      label: Text(isPaid ? 'Pagado' : 'Pendiente'),
      backgroundColor: isPaid
          ? colorScheme.primaryContainer
          : colorScheme.secondaryContainer,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmployeePayrollCard extends ConsumerWidget {
  const _EmployeePayrollCard({
    required this.summary,
    required this.money,
  });

  final EmployeePayrollSummary summary;
  final NumberFormat money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final dayCount = summary.dayGroups.length;
    final lineCount = summary.lines.length;
    final hasMissing = summary.hasMissingRates;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text(
            _initials(summary.employeeName),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          '${summary.employeeCode} - ${summary.employeeName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SmallCountChip(
                icon: Icons.calendar_today_outlined,
                label: '$dayCount dias',
              ),
              _SmallCountChip(
                icon: Icons.list_alt_outlined,
                label: '$lineCount lineas',
              ),
              if (hasMissing)
                const _SmallCountChip(
                  icon: Icons.sell_outlined,
                  label: 'Falta precio',
                ),
            ],
          ),
        ),
        trailing: SizedBox(
          width: 124,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money.format(summary.totalPayable),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              _PaymentStatusChip(isPaid: summary.isPaid),
            ],
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              hasMissing ? 'Faltan precios por asignar' : 'Precios completos',
              style: TextStyle(
                color: hasMissing ? colorScheme.error : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 22),
          for (final dayGroup in summary.dayGroups) ...[
            _PayrollDayBlock(dayGroup: dayGroup, money: money),
            if (dayGroup != summary.dayGroups.last) const Divider(height: 18),
          ],
          const Divider(height: 22),
          _AdjustmentsSection(
            summary: summary,
            money: money,
            onAdd: (type) => _addAdjustment(context, ref, summary, type),
            onDelete: (id) => _deleteAdjustment(context, ref, id),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setPaid(context, ref, false),
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Reabrir'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: hasMissing
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Asigna precio a todos los trabajos antes de pagar.',
                              ),
                            ),
                          );
                        }
                      : () async {
                          final confirmed = await _confirmPayment(context);
                          if (!confirmed) return;
                          if (!context.mounted) return;
                          await _setPaid(context, ref, true);
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar pagado'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _adjustmentLabel(String type) {
    return switch (type) {
      'bonus' => 'Bono',
      'advance' => 'Anticipo',
      'deduction' => 'Descuento',
      _ => type,
    };
  }

  Future<void> _addAdjustment(
    BuildContext context,
    WidgetRef ref,
    EmployeePayrollSummary summary,
    String type,
  ) async {
    final result = await showDialog<_AdjustmentDialogResult>(
      context: context,
      builder: (_) => _AdjustmentDialog(title: _adjustmentLabel(type)),
    );

    if (result == null) return;

    try {
      await ref.read(payrollRepositoryProvider).addAdjustment(
            employeeId: summary.employeeId,
            type: type,
            concept: result.concept,
            amount: result.amount,
          );
      refreshPayrollData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajuste agregado correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo agregar el ajuste: $error')),
        );
      }
    }
  }

  Future<void> _deleteAdjustment(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    try {
      await ref.read(payrollRepositoryProvider).deleteAdjustment(id);
      refreshPayrollData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajuste eliminado correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el ajuste: $error')),
        );
      }
    }
  }

  Future<void> _setPaid(
    BuildContext context,
    WidgetRef ref,
    bool isPaid,
  ) async {
    try {
      await ref.read(payrollRepositoryProvider).setPaid(
            summary.employeeId,
            isPaid,
          );
      refreshPayrollData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPaid
                  ? 'Pago marcado como pagado.'
                  : 'Pago reabierto correctamente.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPaid
                  ? 'No se pudo registrar el pago: $error'
                  : 'No se pudo reabrir el pago: $error',
            ),
          ),
        );
      }
    }
  }

  Future<bool> _confirmPayment(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar pago'),
            content: Text(
              'Se marcara como pagado ${money.format(summary.totalPayable)} '
              'para ${summary.employeeCode} - ${summary.employeeName}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Marcar pagado'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _AdjustmentsSection extends StatelessWidget {
  const _AdjustmentsSection({
    required this.summary,
    required this.money,
    required this.onAdd,
    required this.onDelete,
  });

  final EmployeePayrollSummary summary;
  final NumberFormat money;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonos, anticipos y descuentos',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        if (summary.adjustments.isEmpty)
          const Text('Sin ajustes.')
        else
          for (final adjustment in summary.adjustments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_adjustmentLabel(adjustment.type)),
              subtitle: Text(adjustment.concept),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${adjustment.type == 'bonus' ? '+' : '-'} '
                    '${money.format(adjustment.amount)}',
                  ),
                  IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(adjustment.id),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => onAdd('bonus'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Bono'),
            ),
            OutlinedButton.icon(
              onPressed: () => onAdd('advance'),
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Anticipo'),
            ),
            OutlinedButton.icon(
              onPressed: () => onAdd('deduction'),
              icon: const Icon(Icons.price_change_outlined),
              label: const Text('Descuento'),
            ),
          ],
        ),
      ],
    );
  }

  String _adjustmentLabel(String type) {
    return switch (type) {
      'bonus' => 'Bono',
      'advance' => 'Anticipo',
      'deduction' => 'Descuento',
      _ => type,
    };
  }
}

class _PayrollDayBlock extends StatelessWidget {
  const _PayrollDayBlock({
    required this.dayGroup,
    required this.money,
  });

  final PayrollDayGroup dayGroup;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');
    final colorScheme = Theme.of(context).colorScheme;
    final title = '${_weekdayLabel(dayGroup.date)} '
        '${dateFormat.format(dayGroup.date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              dayGroup.hasMissingRates
                  ? 'Revisar precio'
                  : money.format(dayGroup.total),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dayGroup.hasMissingRates
                        ? colorScheme.error
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final line in dayGroup.lines) ...[
          _PayrollLineTile(line: line, money: money),
          if (line != dayGroup.lines.last) const SizedBox(height: 8),
        ],
      ],
    );
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

class _PayrollOverview extends StatelessWidget {
  const _PayrollOverview({
    required this.gross,
    required this.total,
    required this.readyToPay,
    required this.missingRates,
    required this.workerCount,
    required this.money,
    required this.onCloseWeek,
  });

  final double gross;
  final double total;
  final double readyToPay;
  final int missingRates;
  final int workerCount;
  final NumberFormat money;
  final VoidCallback onCloseWeek;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pagos de la semana',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _SmallCountChip(
                icon: Icons.people_outline,
                label: '$workerCount',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricCard(
                icon: Icons.payments_outlined,
                label: 'Por cancelar',
                value: money.format(total),
              ),
              _MetricCard(
                icon: Icons.verified_outlined,
                label: 'Listo para pagar',
                value: money.format(readyToPay),
              ),
              _MetricCard(
                icon: Icons.work_outline,
                label: 'Trabajo',
                value: money.format(gross),
              ),
              _MetricCard(
                icon: Icons.sell_outlined,
                label: 'Sin precio',
                value: '$missingRates',
                warning: missingRates > 0,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCloseWeek,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Cerrar semana'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollSearchAndFilters extends StatelessWidget {
  const _PayrollSearchAndFilters({
    required this.controller,
    required this.filter,
    required this.onChanged,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final _PayrollFilter filter;
  final VoidCallback onChanged;
  final ValueChanged<_PayrollFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar trabajador',
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar busqueda',
                    onPressed: () {
                      controller.clear();
                      onChanged();
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChipButton(
                label: 'Pendientes',
                icon: Icons.pending_actions,
                selected: filter == _PayrollFilter.pending,
                onSelected: () => onFilterChanged(_PayrollFilter.pending),
              ),
              _FilterChipButton(
                label: 'Listos',
                icon: Icons.verified_outlined,
                selected: filter == _PayrollFilter.ready,
                onSelected: () => onFilterChanged(_PayrollFilter.ready),
              ),
              _FilterChipButton(
                label: 'Sin precio',
                icon: Icons.sell_outlined,
                selected: filter == _PayrollFilter.missingRates,
                onSelected: () => onFilterChanged(_PayrollFilter.missingRates),
              ),
              _FilterChipButton(
                label: 'Pagados',
                icon: Icons.check_circle_outline,
                selected: filter == _PayrollFilter.paid,
                onSelected: () => onFilterChanged(_PayrollFilter.paid),
              ),
              _FilterChipButton(
                label: 'Todos',
                icon: Icons.list_alt_outlined,
                selected: filter == _PayrollFilter.all,
                onSelected: () => onFilterChanged(_PayrollFilter.all),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 18,
          color: selected ? colorScheme.onPrimary : colorScheme.primary,
        ),
        label: Text(label),
        selectedColor: colorScheme.primary,
        labelStyle: TextStyle(
          color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _SmallCountChip extends StatelessWidget {
  const _SmallCountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPayrollFilter extends StatelessWidget {
  const _EmptyPayrollFilter();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text(
              'No hay trabajadores con este filtro.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PayrollLineTile extends ConsumerWidget {
  const _PayrollLineTile({
    required this.line,
    required this.money,
  });

  final PayrollLine line;
  final NumberFormat money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _iconForUnit(line.unit),
              color: colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.workTypeName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(_quantityText(line.quantity, line.unit)),
                Text(
                  !line.hasRate
                      ? 'Sin precio asignado'
                      : '${money.format(line.rate)} x unidad',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: !line.hasRate
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!line.hasRate)
            OutlinedButton(
              onPressed: () => _assignRate(context, ref),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Asignar'),
            )
          else
            Text(
              money.format(line.subtotal),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
        ],
      ),
    );
  }

  IconData _iconForUnit(String unit) {
    return switch (unit) {
      'hour' => Icons.schedule_outlined,
      'day' => Icons.calendar_today_outlined,
      'bag' => Icons.shopping_bag_outlined,
      'bucket' => Icons.inventory_2_outlined,
      'tray' => Icons.table_bar_outlined,
      _ => Icons.work_outline,
    };
  }

  Future<void> _assignRate(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _AssignRateDialog(workTypeName: line.workTypeName),
    );

    if (value == null || value < 0) return;

    try {
      await ref.read(ratesRepositoryProvider).save(
            workTypeId: line.workTypeId,
            employeeId: line.employeeId,
            unitPrice: value,
            validFrom: line.workDate,
            validUntil: null,
            active: true,
          );
      refreshRateData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Precio asignado correctamente.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el precio: $error')),
        );
      }
    }
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

  String _quantityText(double quantity, String unit) {
    if (unit == 'hour') return _formatHours(quantity);
    final formattedQuantity = quantity == quantity.roundToDouble()
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);
    return '$formattedQuantity ${_unitLabel(unit)}';
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '$h h';
    return '$h h ${minutes.toString().padLeft(2, '0')} min';
  }
}

class _AdjustmentDialogResult {
  const _AdjustmentDialogResult({
    required this.amount,
    required this.concept,
  });

  final double amount;
  final String concept;
}

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog({required this.title});

  final String title;

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _conceptController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _conceptController.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    final concept = _conceptController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto mayor que cero.')),
      );
      return;
    }

    if (concept.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el concepto del ajuste.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _AdjustmentDialogResult(amount: amount, concept: concept),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: 'Bs ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conceptController,
              decoration: const InputDecoration(labelText: 'Concepto'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
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
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _AssignRateDialog extends StatefulWidget {
  const _AssignRateDialog({required this.workTypeName});

  final String workTypeName;

  @override
  State<_AssignRateDialog> createState() => _AssignRateDialogState();
}

class _AssignRateDialogState extends State<_AssignRateDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(
      _controller.text.trim().replaceAll(',', '.'),
    );

    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un precio valido.')),
      );
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asignar precio'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Precio para ${widget.workTypeName}',
          prefixText: 'Bs ',
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
