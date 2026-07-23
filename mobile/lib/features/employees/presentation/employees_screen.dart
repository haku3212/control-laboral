import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/employee.dart';
import '../data/employees_repository.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar trabajador',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: employees,
              data: (items) {
                final filtered = items
                    .where((e) =>
                        e.fullName.toLowerCase().contains(_query) ||
                        e.code.toLowerCase().contains(_query))
                    .toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Sin trabajadores',
                    message: 'Crea el primer trabajador para comenzar.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(employeesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final employee = filtered[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(employee.code[0])),
                          title: Text(employee.fullName),
                          subtitle: Text(employee.jobTitle ?? employee.code),
                          trailing: Switch(
                            value: employee.active,
                            onChanged: (value) async {
                              await ref
                                  .read(employeesRepositoryProvider)
                                  .setActive(employee.id, value);
                              ref.invalidate(employeesProvider);
                            },
                          ),
                          onTap: () => _openForm(employee),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Crear'),
      ),
    );
  }

  Future<void> _openForm(Employee? employee) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EmployeeForm(employee: employee),
    );
    ref.invalidate(employeesProvider);
  }
}

class _EmployeeForm extends ConsumerStatefulWidget {
  const _EmployeeForm({this.employee});

  final Employee? employee;

  @override
  ConsumerState<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<_EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _document;
  late final TextEditingController _jobTitle;
  late final TextEditingController _notes;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _code = TextEditingController(text: employee?.code);
    _name = TextEditingController(text: employee?.fullName);
    _document = TextEditingController(text: employee?.documentNumber);
    _jobTitle = TextEditingController(text: employee?.jobTitle);
    _notes = TextEditingController(text: employee?.notes);
    _active = employee?.active ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _document.dispose();
    _jobTitle.dispose();
    _notes.dispose();
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
                widget.employee == null ? 'Crear trabajador' : 'Editar trabajador',
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
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _document,
                decoration: const InputDecoration(labelText: 'Documento'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jobTitle,
                decoration: const InputDecoration(labelText: 'Cargo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 3,
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
      await ref.read(employeesRepositoryProvider).save(
            id: widget.employee?.id,
            code: _code.text,
            fullName: _name.text,
            documentNumber: _document.text,
            jobTitle: _jobTitle.text,
            notes: _notes.text,
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
