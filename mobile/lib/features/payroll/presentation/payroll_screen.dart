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
        final pendingItems = items.where((item) => !item.isPaid).toList();

        if (pendingItems.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay pagos pendientes por cancelar.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final gross =
            pendingItems.fold(0.0, (sum, item) => sum + item.grossPayable);
        final total =
            pendingItems.fold(0.0, (sum, item) => sum + item.totalPayable);
        final missingRates =
            pendingItems.where((item) => item.hasMissingRates).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(payrollSummariesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Pagos pendientes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricCard(
                    icon: Icons.work_outline,
                    label: 'Trabajo',
                    value: money.format(gross),
                  ),
                  _MetricCard(
                    icon: Icons.payments_outlined,
                    label: 'Por cancelar',
                    value: money.format(total),
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
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(payrollRepositoryProvider)
                        .closeCurrentWeek();
                    ref.invalidate(payrollSummariesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Semana cerrada correctamente.'),
                        ),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No se pudo cerrar la semana: $error'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.lock_outline),
                label: const Text('Cerrar semana'),
              ),
              const SizedBox(height: 16),
              for (final item in pendingItems) ...[
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
                      '${summary.employeeCode} - ${summary.employeeName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text('Se pagó'),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money.format(summary.totalPayable)),
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(payrollRepositoryProvider)
                            .setPaid(summary.employeeId, false);
                        ref.invalidate(payrollSummariesProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pago reabierto correctamente.'),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('No se pudo reabrir el pago: $error'),
                            ),
                          );
                        }
                      }
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
                    '${summary.employeeCode} - ${summary.employeeName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money.format(summary.totalPayable)),
                    _PaymentStatusChip(isPaid: summary.isPaid),
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
            Text(
              'Bonos, anticipos y descuentos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
                        '${adjustment.type == 'bonus' ? '+' : '-'} '
                        '${money.format(adjustment.amount)}',
                      ),
                      IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await ref
                                .read(payrollRepositoryProvider)
                                .deleteAdjustment(adjustment.id);
                            ref.invalidate(payrollSummariesProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Ajuste eliminado correctamente.'),
                                ),
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'No se pudo eliminar el ajuste: $error'),
                                ),
                              );
                            }
                          }
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
                  onPressed: () =>
                      _addAdjustment(context, ref, summary, 'bonus'),
                  child: const Text('Bono'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _addAdjustment(context, ref, summary, 'advance'),
                  child: const Text('Anticipo'),
                ),
                OutlinedButton(
                  onPressed: () =>
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
                      try {
                        await ref
                            .read(payrollRepositoryProvider)
                            .setPaid(summary.employeeId, false);
                        ref.invalidate(payrollSummariesProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pago reabierto correctamente.'),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('No se pudo reabrir el pago: $error'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Reabrir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final confirmed = await _confirmPayment(context);
                      if (!confirmed) return;
                      try {
                        await ref
                            .read(payrollRepositoryProvider)
                            .setPaid(summary.employeeId, true);
                        ref.invalidate(payrollSummariesProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pago marcado como pagado.'),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('No se pudo registrar el pago: $error'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marcar pagado'),
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
      ref.invalidate(payrollSummariesProvider);
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

  Future<bool> _confirmPayment(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar pago'),
            content: Text(
              'Se marcará como pagado ${money.format(summary.totalPayable)} '
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
              Text('$quantity ${_unitLabel(line.unit)}'),
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
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _AssignRateDialog(workTypeName: line.workTypeName),
    );

    if (value == null || value < 0) return;

    try {
      await ref.read(ratesRepositoryProvider).save(
            workTypeId: line.workTypeId,
            employeeId: null,
            unitPrice: value,
            validFrom: DateTime.now(),
            validUntil: null,
            active: true,
          );
      ref.invalidate(payrollSummariesProvider);
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
      'unit' => 'unid.',
      'service' => 'serv.',
      'bag' => 'bolsa',
      'bucket' => 'tacho',
      'tray' => 'bandeja',
      _ => value,
    };
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
        const SnackBar(content: Text('Ingresa un precio válido.')),
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
