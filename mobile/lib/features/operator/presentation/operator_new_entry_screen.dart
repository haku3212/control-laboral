import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/profile_provider.dart';
import '../../employees/data/employee.dart';
import '../../employees/data/employees_repository.dart';
import '../../work_types/data/work_type.dart';
import '../../work_types/data/work_types_repository.dart';
import '../data/operator_entries_repository.dart';

class OperatorNewEntryScreen extends ConsumerStatefulWidget {
  const OperatorNewEntryScreen({super.key});

  @override
  ConsumerState<OperatorNewEntryScreen> createState() => _OperatorNewEntryScreenState();
}

class _OperatorNewEntryScreenState extends ConsumerState<OperatorNewEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  final _newEmployee = TextEditingController();
  final _newWorkType = TextEditingController();
  final _inlineEmployee = TextEditingController();
  final _inlineWorkType = TextEditingController();
  String? _employeeId;
  String? _workTypeId;
  DateTime _workDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    _newEmployee.dispose();
    _newWorkType.dispose();
    _inlineEmployee.dispose();
    _inlineWorkType.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workTypes = ref.watch(workTypesProvider);
    final employees = ref.watch(employeesProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Nuevo registro',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('El registro quedara pendiente hasta que el admin lo revise.'),
          const SizedBox(height: 16),
          employees.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('No se cargaron trabajadores: $error'),
            data: (items) => _employeeDropdown(items.where((e) => e.active).toList()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _inlineEmployee,
            decoration: const InputDecoration(
              labelText: 'Escribir trabajador si no esta en la lista',
              prefixIcon: Icon(Icons.person_add_alt),
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty && _employeeId != null) {
                setState(() => _employeeId = null);
              }
            },
          ),
          TextButton.icon(
            onPressed: _createEmployee,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Guardar nuevo trabajador'),
          ),
          const SizedBox(height: 8),
          workTypes.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('No se cargaron tipos de trabajo: $error'),
            data: (items) => _workTypeDropdown(items.where((e) => e.active).toList()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _inlineWorkType,
            decoration: const InputDecoration(
              labelText: 'Escribir trabajo si no esta en la lista',
              prefixIcon: Icon(Icons.edit_note_outlined),
              hintText: 'Ej: Fundir silicato',
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty && _workTypeId != null) {
                setState(() => _workTypeId = null);
              }
            },
          ),
          TextButton.icon(
            onPressed: _createWorkType,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Guardar nuevo trabajo'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              prefixIcon: Icon(Icons.numbers),
            ),
            validator: (value) {
              final parsed = double.tryParse(value?.replaceAll(',', '.') ?? '');
              if (parsed == null || parsed <= 0) return 'Ingresa una cantidad valida';
              return null;
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha'),
            subtitle: Text(dateFormat.format(_workDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Notas del trabajo',
              prefixIcon: Icon(Icons.notes_outlined),
              hintText: 'Ej: trabajo en cisterna grande, llego tarde, faltaron bolsas',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar registro'),
          ),
        ],
      ),
    );
  }

  Widget _workTypeDropdown(List<WorkType> items) {
    return DropdownButtonFormField<String>(
      value: _workTypeId,
      decoration: const InputDecoration(
        labelText: 'Tipo de trabajo',
        prefixIcon: Icon(Icons.work_outline),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item.id,
            child: Text('${item.name} (${item.unit})'),
          ),
      ],
      onChanged: (value) => setState(() => _workTypeId = value),
    );
  }

  Widget _employeeDropdown(List<Employee> items) {
    return DropdownButtonFormField<String>(
      value: _employeeId,
      decoration: const InputDecoration(
        labelText: 'Trabajador',
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.fullName)),
      ],
      onChanged: (value) => setState(() => _employeeId = value),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      initialDate: _workDate,
    );
    if (picked != null) {
      setState(() => _workDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null || !profile.isOperator) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu usuario no puede enviar registros.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final employeeId = await _resolveEmployeeId();
      final workTypeId = await _resolveWorkTypeId();
      if (employeeId == null || workTypeId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona o escribe trabajador y trabajo.'),
          ),
        );
        return;
      }

      await ref.read(operatorEntriesRepositoryProvider).create(
            employeeId: employeeId,
            workTypeId: workTypeId,
            workDate: _workDate,
            quantity: double.parse(_quantity.text.replaceAll(',', '.')),
            note: _note.text,
          );
      ref.invalidate(operatorEntriesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro enviado para revision.')),
      );
      context.go('/operator/entries');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createEmployee() async {
    final name = await _askText(
      title: 'Agregar trabajador',
      label: 'Nombre del trabajador',
      controller: _newEmployee,
    );
    if (name == null) return;
    final code = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final employee = await ref.read(employeesRepositoryProvider).saveReturning(
          code: code.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : code,
          fullName: name,
        );
    setState(() => _employeeId = employee.id);
    ref.invalidate(employeesProvider);
  }

  Future<void> _createWorkType() async {
    final name = await _askText(
      title: 'Agregar trabajo',
      label: 'Nombre del trabajo',
      controller: _newWorkType,
    );
    if (name == null) return;
    final code = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final workType = await ref.read(workTypesRepositoryProvider).saveReturning(
          code: code.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : code,
          name: name,
          unit: 'unit',
          category: 'quantity',
          active: true,
        );
    setState(() => _workTypeId = workType.id);
    ref.invalidate(workTypesProvider);
  }

  Future<String?> _resolveEmployeeId() async {
    if (_inlineEmployee.text.trim().isEmpty) return _employeeId;
    final id = await _createEmployeeFromName(_inlineEmployee.text.trim());
    _inlineEmployee.clear();
    ref.invalidate(employeesProvider);
    return id;
  }

  Future<String?> _resolveWorkTypeId() async {
    if (_inlineWorkType.text.trim().isEmpty) return _workTypeId;
    final id = await _createWorkTypeFromName(_inlineWorkType.text.trim());
    _inlineWorkType.clear();
    ref.invalidate(workTypesProvider);
    return id;
  }

  Future<String> _createEmployeeFromName(String name) async {
    final code = _codeFromName(name);
    final row = await ref.read(employeesRepositoryProvider).saveReturning(
          code: code,
          fullName: name,
        );
    return row.id;
  }

  Future<String> _createWorkTypeFromName(String name) async {
    final code = _codeFromName(name);
    final row = await ref.read(workTypesRepositoryProvider).saveReturning(
          code: code,
          name: name,
          unit: 'unit',
          category: 'quantity',
          active: true,
        );
    return row.id;
  }

  String _codeFromName(String name) {
    final code = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return code.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : code;
  }

  Future<String?> _askText({
    required String title,
    required String label,
    required TextEditingController controller,
  }) async {
    controller.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop(value.isEmpty ? null : value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
