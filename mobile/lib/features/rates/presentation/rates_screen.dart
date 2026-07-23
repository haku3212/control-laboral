import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../employees/data/employee.dart';
import '../../employees/data/employees_repository.dart';
import '../../work_types/data/work_type.dart';
import '../../work_types/data/work_types_repository.dart';
import '../data/rate.dart';
import '../data/rates_repository.dart';

class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rates = ref.watch(ratesProvider);
    final money = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ');
    final date = DateFormat('dd/MM/yyyy', 'es_BO');

    return Scaffold(
      body: AsyncValueView(
        value: rates,
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.price_change_outlined,
              title: 'Sin tarifas',
              message: 'Crea tarifas generales o especiales por trabajador.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ratesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final rate = items[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text('${rate.workTypeName} - ${money.format(rate.unitPrice)}'),
                    subtitle: Text(
                      '${rate.employeeName ?? 'Tarifa general'}\nDesde ${date.format(rate.validFrom)}',
                    ),
                    isThreeLine: true,
                    trailing: rate.active
                        ? const Icon(Icons.check_circle_outline)
                        : const Icon(Icons.pause_circle_outline),
                    onTap: () => _openForm(context, ref, rate),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Crear'),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, Rate? rate) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RateForm(rate: rate),
    );
    ref.invalidate(ratesProvider);
  }
}

class _RateForm extends ConsumerStatefulWidget {
  const _RateForm({this.rate});

  final Rate? rate;

  @override
  ConsumerState<_RateForm> createState() => _RateFormState();
}

class _RateFormState extends ConsumerState<_RateForm> {
  final _formKey = GlobalKey<FormState>();
  final _price = TextEditingController();
  String? _workTypeId;
  String? _employeeId;
  late DateTime _validFrom;
  DateTime? _validUntil;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rate = widget.rate;
    _workTypeId = rate?.workTypeId;
    _employeeId = rate?.employeeId;
    _price.text = rate == null ? '' : rate.unitPrice.toStringAsFixed(2);
    _validFrom = rate?.validFrom ?? DateTime.now();
    _validUntil = rate?.validUntil;
    _active = rate?.active ?? true;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workTypes = ref.watch(workTypesProvider);
    final employees = ref.watch(employeesProvider);
    final date = DateFormat('dd/MM/yyyy', 'es_BO');

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.rate == null ? 'Crear tarifa' : 'Editar tarifa',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              workTypes.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Error tipos: $error'),
                data: (items) => _workTypeDropdown(items),
              ),
              const SizedBox(height: 12),
              employees.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Error trabajadores: $error'),
                data: (items) => _employeeDropdown(items),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio unitario'),
                validator: (value) {
                  final parsed = double.tryParse(value?.replaceAll(',', '.') ?? '');
                  if (parsed == null || parsed < 0) return 'Monto invalido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vigente desde'),
                subtitle: Text(date.format(_validFrom)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () => _pickDate(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vigente hasta'),
                subtitle: Text(_validUntil == null ? 'Sin fin' : date.format(_validUntil!)),
                trailing: const Icon(Icons.event_busy_outlined),
                onTap: () => _pickDate(false),
              ),
              SwitchListTile(
                value: _active,
                title: const Text('Activa'),
                onChanged: (value) => setState(() => _active = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workTypeDropdown(List<WorkType> items) {
    return DropdownButtonFormField<String>(
      value: _workTypeId,
      decoration: const InputDecoration(labelText: 'Tipo de trabajo'),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.name)),
      ],
      validator: (value) => value == null ? 'Requerido' : null,
      onChanged: (value) => setState(() => _workTypeId = value),
    );
  }

  Widget _employeeDropdown(List<Employee> items) {
    return DropdownButtonFormField<String?>(
      value: _employeeId,
      decoration: const InputDecoration(labelText: 'Trabajador'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Tarifa general')),
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.fullName)),
      ],
      onChanged: (value) => setState(() => _employeeId = value),
    );
  }

  Future<void> _pickDate(bool from) async {
    final initial = from ? _validFrom : (_validUntil ?? _validFrom);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _validFrom = picked;
      } else {
        _validUntil = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar tarifa'),
        content: const Text('Los cambios de tarifa afectan calculos futuros.'),
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
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(ratesRepositoryProvider).save(
            id: widget.rate?.id,
            workTypeId: _workTypeId!,
            employeeId: _employeeId,
            unitPrice: double.parse(_price.text.replaceAll(',', '.')),
            validFrom: _validFrom,
            validUntil: _validUntil,
            active: _active,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
