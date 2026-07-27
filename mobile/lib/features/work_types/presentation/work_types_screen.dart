import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/work_type.dart';
import '../data/work_types_repository.dart';

const units = ['hour', 'unit', 'service', 'bag', 'bucket', 'tray'];
const categories = ['hourly', 'quantity', 'attendance'];

String unitLabel(String value) {
  return switch (value) {
    'hour' => 'Hora',
    'unit' => 'Unidad',
    'service' => 'Servicio',
    'bag' => 'Bolsa',
    'bucket' => 'Tacho',
    'tray' => 'Bandeja',
    _ => value,
  };
}

String categoryLabel(String value) {
  return switch (value) {
    'hourly' => 'Por horas',
    'quantity' => 'Por cantidad',
    'attendance' => 'Asistencia',
    _ => value,
  };
}

class WorkTypesScreen extends ConsumerWidget {
  const WorkTypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workTypes = ref.watch(workTypesProvider);
    return Scaffold(
      body: AsyncValueView(
        value: workTypes,
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.work_outline,
              title: 'Sin tipos de trabajo',
              message: 'Carga el seed o crea un tipo nuevo.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(workTypesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        item.category == 'hourly'
                            ? Icons.schedule
                            : Icons.inventory_2_outlined,
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.code} - ${unitLabel(item.unit)} - ${categoryLabel(item.category)}',
                    ),
                    trailing: Chip(
                      avatar: Icon(
                        item.active
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        size: 18,
                      ),
                      label: Text(item.active ? 'Activo' : 'Pausado'),
                      side: BorderSide.none,
                    ),
                    onTap: () => _openForm(context, ref, item),
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

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    WorkType? item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _WorkTypeForm(item: item),
    );
    ref.invalidate(workTypesProvider);
  }
}

class _WorkTypeForm extends ConsumerStatefulWidget {
  const _WorkTypeForm({this.item});

  final WorkType? item;

  @override
  ConsumerState<_WorkTypeForm> createState() => _WorkTypeFormState();
}

class _WorkTypeFormState extends ConsumerState<_WorkTypeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late String _unit;
  late String _category;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _code = TextEditingController(text: item?.code);
    _name = TextEditingController(text: item?.name);
    _unit = item?.unit ?? units.first;
    _category = item?.category ?? categories.first;
    _active = item?.active ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.item == null
                    ? 'Crear tipo de trabajo'
                    : 'Editar tipo de trabajo',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unidad',
                  prefixIcon: Icon(Icons.straighten_outlined),
                ),
                items: [
                  for (final unit in units)
                    DropdownMenuItem(value: unit, child: Text(unitLabel(unit))),
                ],
                onChanged: (value) => setState(() {
                  _unit = value ?? _unit;
                  _category = _unit == 'hour' ? 'hourly' : _category;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(categoryLabel(category)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                title: const Text('Activo'),
                subtitle: const Text('Disponible para nuevos registros'),
                onChanged: (value) => setState(() => _active = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando...' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Requerido' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(workTypesRepositoryProvider).save(
            id: widget.item?.id,
            code: _code.text,
            name: _name.text,
            unit: _unit,
            category: _category,
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
