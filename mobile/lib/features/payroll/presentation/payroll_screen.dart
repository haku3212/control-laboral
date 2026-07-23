import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../rates/data/rates_repository.dart';
import '../data/payroll_repository.dart';
import '../data/payroll_summary.dart';

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(payrollSummariesProvider);
    final money = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ');

    return AsyncValueView(
      value: summaries,
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay registros confirmados para calcular pagos.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final gross = items.fold(0.0, (sum, item) => sum + item.grossPayable);
        final total = items.fold(0.0, (sum, item) => sum + item.totalPayable);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(payrollSummariesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Pagos estimados',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('Total trabajo: ${money.format(gross)}'),
              Text('A pagar: ${money.format(total)}'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(payrollRepositoryProvider).closeCurrentWeek();
                  ref.invalidate(payrollSummariesProvider);
                },
                icon: const Icon(Icons.lock_outline),
                label: const Text('Cerrar semana'),
              ),
              const SizedBox(height: 16),
              for (final item in items) ...[
                _EmployeePayrollCard(summary: item, money: money),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
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
    if (summary.isPaid) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.employeeName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text('Se pago'),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money.format(summary.totalPayable)),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(payrollRepositoryProvider)
                          .setPaid(summary.employeeId, false);
                      ref.invalidate(payrollSummariesProvider);
                    },
                    child: const Text('Reabrir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.employeeName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money.format(summary.totalPayable)),
                    Text(summary.isPaid ? 'Pagado' : 'Pendiente'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              summary.hasMissingRates
                  ? 'Faltan precios por asignar'
                  : 'Precios completos',
            ),
            const Divider(height: 22),
            for (final line in summary.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PayrollLineTile(line: line, money: money),
              ),
            const Divider(height: 22),
            Text('Bonos, anticipos y descuentos',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (summary.adjustments.isEmpty)
              const Text('Sin ajustes.')
            else
              for (final adjustment in summary.adjustments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_adjustmentLabel(adjustment.type)),
                  subtitle: Text(adjustment.concept),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${adjustment.type == 'bonus' ? '+' : '-'} ${money.format(adjustment.amount)}',
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: summary.isPaid
                            ? null
                            : () async {
                                await ref
                                    .read(payrollRepositoryProvider)
                                    .deleteAdjustment(adjustment.id);
                                ref.invalidate(payrollSummariesProvider);
                              },
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: summary.isPaid
                      ? null
                      : () => _addAdjustment(context, ref, summary, 'bonus'),
                  child: const Text('Bono'),
                ),
                OutlinedButton(
                  onPressed: summary.isPaid
                      ? null
                      : () => _addAdjustment(context, ref, summary, 'advance'),
                  child: const Text('Anticipo'),
                ),
                OutlinedButton(
                  onPressed: summary.isPaid
                      ? null
                      : () =>
                          _addAdjustment(context, ref, summary, 'deduction'),
                  child: const Text('Descuento'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(payrollRepositoryProvider)
                          .setPaid(summary.employeeId, false);
                      ref.invalidate(payrollSummariesProvider);
                    },
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Reabrir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref
                          .read(payrollRepositoryProvider)
                          .setPaid(summary.employeeId, true);
                      ref.invalidate(payrollSummariesProvider);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Pagado'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  Future<void> _addAdjustment(
    BuildContext context,
    WidgetRef ref,
    EmployeePayrollSummary summary,
    String type,
  ) async {
    final amountController = TextEditingController();
    final conceptController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_adjustmentLabel(type)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: 'Bs ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: conceptController,
              decoration: const InputDecoration(labelText: 'Concepto'),
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
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    final concept = conceptController.text;
    amountController.dispose();
    conceptController.dispose();
    if (saved != true || amount == null || amount <= 0) return;

    await ref.read(payrollRepositoryProvider).addAdjustment(
          employeeId: summary.employeeId,
          type: type,
          concept: concept,
          amount: amount,
        );
    ref.invalidate(payrollSummariesProvider);
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
    final quantity = line.quantity == line.quantity.roundToDouble()
        ? line.quantity.toStringAsFixed(0)
        : line.quantity.toStringAsFixed(2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.workTypeName),
              Text('$quantity ${line.unit}'),
              Text(
                line.rate == null
                    ? 'Sin precio'
                    : '${money.format(line.rate)} x unidad',
              ),
            ],
          ),
        ),
        if (line.rate == null)
          OutlinedButton(
            onPressed: () => _assignRate(context, ref),
            child: const Text('Asignar'),
          )
        else
          Text(money.format(line.subtotal!)),
      ],
    );
  }

  Future<void> _assignRate(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asignar precio'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Precio para ${line.workTypeName}',
            prefixText: 'Bs ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value < 0) return;

    await ref.read(ratesRepositoryProvider).save(
          workTypeId: line.workTypeId,
          employeeId: null,
          unitPrice: value,
          validFrom: DateTime.now(),
          validUntil: null,
          active: true,
        );
    ref.invalidate(payrollSummariesProvider);
  }
}
