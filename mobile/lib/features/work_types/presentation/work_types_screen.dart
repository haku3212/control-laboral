import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/work_type.dart';
import '../data/work_types_repository.dart';

const units = ['hour', 'unit', 'service', 'bag', 'bucket', 'tray'];
const categories = ['hourly', 'quantity', 'attendance'];

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
                    leading: Icon(
                      item.category == 'hourly'
                          ? Icons.schedule
                          : Icons.inventory_2_outlined,
                    ),
                    title: Text(item.name),
                    subtitle: Text('${item.code} - ${item.unit} - ${item.category}'),
                    trailing: item.active
                        ? const Icon(Icons.check_circle_outline)
                        : const Icon(Icons.pause_circle_outline),
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

  Future<void> _openForm(BuildContext context, WidgetRef ref, WorkType? item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                widget.item == null ? 'Crear tipo de trabajo' : 'Editar tipo de trabajo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Codigo'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(labelText: 'Unidad'),
                items: [
                  for (final unit in units)
                    DropdownMenuItem(value: unit, child: Text(unit)),
                ],
                onChanged: (value) => setState(() => _unit = value ?? _unit),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              SwitchListTile(
                value: _active,
                title: const Text('Activo'),
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
