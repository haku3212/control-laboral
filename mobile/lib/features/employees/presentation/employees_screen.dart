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
                hintText: 'Nombre, código, CI o teléfono',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() => _query = value.toLowerCase().trim());
              },
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: employees,
              data: (items) {
                final filtered = items.where((employee) {
                  return employee.fullName.toLowerCase().contains(_query) ||
                      employee.code.toLowerCase().contains(_query) ||
                      (employee.documentNumber ?? '')
                          .toLowerCase()
                          .contains(_query) ||
                      (employee.phone ?? '')
                          .toLowerCase()
                          .contains(_query) ||
                      (employee.jobTitle ?? '')
                          .toLowerCase()
                          .contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Sin trabajadores',
                    message: 'Crea el primer trabajador para comenzar.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(employeesProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final employee = filtered[index];

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openForm(employee),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  child: Text(
                                    _initials(employee.fullName),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        employee.fullName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      _EmployeeInfoLine(
                                        icon: Icons.badge_outlined,
                                        text: 'Código: ${employee.code}',
                                      ),
                                      if ((employee.documentNumber ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        _EmployeeInfoLine(
                                          icon: Icons.credit_card_outlined,
                                          text:
                                              'CI: ${employee.documentNumber}',
                                        ),
                                      if ((employee.phone ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        _EmployeeInfoLine(
                                          icon: Icons.phone_outlined,
                                          text: employee.phone!,
                                        ),
                                      if ((employee.jobTitle ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        _EmployeeInfoLine(
                                          icon: Icons.work_outline,
                                          text: employee.jobTitle!,
                                        ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: employee.active,
                                  onChanged: (value) async {
                                    if (!value) {
                                      final confirmed =
                                          await _confirmDeactivate(
                                        context,
                                        employee.fullName,
                                      );

                                      if (!confirmed) return;
                                    }

                                    await ref
                                        .read(employeesRepositoryProvider)
                                        .setActive(employee.id, value);

                                    ref.invalidate(employeesProvider);
                                  },
                                ),
                              ],
                            ),
                          ),
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

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _openForm(Employee? employee) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EmployeeForm(employee: employee),
    );

    ref.invalidate(employeesProvider);
  }

  Future<bool> _confirmDeactivate(
    BuildContext context,
    String employeeName,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Desactivar trabajador'),
            content: Text(
              'El historial de $employeeName se conservará. '
              'Solo dejará de aparecer como activo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Desactivar'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _EmployeeInfoLine extends StatelessWidget {
  const _EmployeeInfoLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
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
  late final TextEditingController _phone;
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
    _phone = TextEditingController(text: employee?.phone);
    _jobTitle = TextEditingController(text: employee?.jobTitle);
    _notes = TextEditingController(text: employee?.notes);
    _active = employee?.active ?? true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _document.dispose();
    _phone.dispose();
    _jobTitle.dispose();
    _notes.dispose();

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
                widget.employee == null
                    ? 'Crear trabajador'
                    : 'Editar trabajador',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Información personal',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _document,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CI',
                  prefixIcon: Icon(Icons.credit_card_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Información laboral',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jobTitle,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Cargo',
                  prefixIcon: Icon(Icons.work_outline),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Información adicional',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                title: const Text('Trabajador activo'),
                subtitle: Text(
                  _active
                      ? 'Puede aparecer en jornadas y asignaciones.'
                      : 'Se conservará su historial.',
                ),
                onChanged: (value) {
                  setState(() => _active = value);
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving ? 'Guardando...' : 'Guardar trabajador',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Requerido' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await ref.read(employeesRepositoryProvider).save(
            id: widget.employee?.id,
            code: _code.text,
            fullName: _name.text,
            documentNumber: _document.text,
            phone: _phone.text,
            jobTitle: _jobTitle.text,
            notes: _notes.text,
            active: _active,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}