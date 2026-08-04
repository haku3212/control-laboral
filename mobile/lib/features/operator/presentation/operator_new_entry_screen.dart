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
  ConsumerState<OperatorNewEntryScreen> createState() =>
      _OperatorNewEntryScreenState();
}

class _OperatorNewEntryScreenState
    extends ConsumerState<OperatorNewEntryScreen> {
  DateTime _workDate = DateTime.now();
  String? _employeeId;
  bool _saving = false;

  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _noteControllers = {};
  final Map<String, TimeOfDay?> _startTimes = {};
  final Map<String, TimeOfDay?> _endTimes = {};

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    final workTypes = ref.watch(workTypesProvider);
    final permissions = ref.watch(employeeAllowedWorkTypeIdsMapProvider);
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SheetHeader(
          date: dateFormat.format(_workDate),
          onPickDate: _pickDate,
        ),
        const SizedBox(height: 12),
        employees.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('No se cargaron trabajadores: $error'),
          data: (employeeItems) => workTypes.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('No se cargaron trabajos: $error'),
            data: (workTypeItems) => permissions.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) =>
                  Text('No se cargaron trabajos permitidos: $error'),
              data: (permissionMap) {
                final activeEmployees =
                    employeeItems.where((item) => item.active).toList();
                final activeWorkTypes =
                    workTypeItems.where((item) => item.active).toList();

                if (activeEmployees.isEmpty) {
                  return const _SimpleNotice(
                    icon: Icons.groups_outlined,
                    title: 'Sin trabajadores activos',
                    message:
                        'Crea trabajadores para llenar la planilla diaria.',
                  );
                }

                final selectedEmployee = _selectedEmployee(activeEmployees);
                final selectedWorkTypes = selectedEmployee == null
                    ? const <WorkType>[]
                    : _allowedWorkTypes(
                        selectedEmployee,
                        activeWorkTypes,
                        permissionMap,
                      );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EmployeePicker(
                      employees: activeEmployees,
                      employeeId: _employeeId,
                      onChanged: (value) {
                        setState(() {
                          _employeeId = value;
                          _clearAll();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedEmployee == null)
                      const _SimpleNotice(
                        icon: Icons.person_search_outlined,
                        title: 'Selecciona trabajador',
                        message:
                            'Primero elige un trabajador para ver sus trabajos asignados.',
                      )
                    else ...[
                      _EmployeeSheetSection(
                        employee: selectedEmployee,
                        workTypes: selectedWorkTypes,
                        quantityController: (workTypeId) => _quantityController(
                            selectedEmployee.id, workTypeId),
                        noteController: _noteController(selectedEmployee.id),
                        startTime: _startTimes[selectedEmployee.id],
                        endTime: _endTimes[selectedEmployee.id],
                        restMinutes: _automaticRestMinutes(selectedEmployee.id),
                        onPickStart: () =>
                            _pickTime(selectedEmployee.id, isStart: true),
                        onPickEnd: () =>
                            _pickTime(selectedEmployee.id, isStart: false),
                        onClear: () => _clearEmployee(selectedEmployee.id),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _submitSheet(
                                  selectedEmployee,
                                  selectedWorkTypes,
                                ),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _saving ? 'Guardando...' : 'Guardar trabajador',
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Employee? _selectedEmployee(List<Employee> activeEmployees) {
    final employeeId = _employeeId;
    if (employeeId == null) return null;
    for (final employee in activeEmployees) {
      if (employee.id == employeeId) return employee;
    }
    return null;
  }

  List<WorkType> _allowedWorkTypes(
    Employee employee,
    List<WorkType> activeWorkTypes,
    Map<String, Set<String>> permissionMap,
  ) {
    if (!employee.restrictWorkTypes) return activeWorkTypes;
    final allowedIds = permissionMap[employee.id] ?? <String>{};
    return activeWorkTypes
        .where((item) => allowedIds.contains(item.id))
        .toList();
  }

  TextEditingController _quantityController(
    String employeeId,
    String workTypeId,
  ) {
    final key = '$employeeId:$workTypeId';
    return _quantityControllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  TextEditingController _noteController(String employeeId) {
    return _noteControllers.putIfAbsent(
      employeeId,
      () => TextEditingController(),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      initialDate: _workDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _workDate = picked);
  }

  Future<void> _pickTime(String employeeId, {required bool isStart}) async {
    final current = isStart ? _startTimes[employeeId] : _endTimes[employeeId];
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTimes[employeeId] = picked;
      } else {
        _endTimes[employeeId] = picked;
      }
    });
  }

  Future<void> _submitSheet(
    Employee employee,
    List<WorkType> workTypes,
  ) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null || !profile.isOperator) {
      _showMessage('Tu usuario no puede enviar registros.');
      return;
    }

    final drafts = <OperatorEntryDraft>[];
    final note = _noteController(employee.id).text;
    final startTime = _toParts(_startTimes[employee.id]);
    final endTime = _toParts(_endTimes[employee.id]);
    final restMinutes = _automaticRestMinutes(employee.id);

    for (final workType in workTypes) {
      final controller = _quantityController(employee.id, workType.id);
      final quantity = _parseQuantity(controller.text);
      if (quantity == null || quantity <= 0) continue;

      drafts.add(
        OperatorEntryDraft(
          employeeId: employee.id,
          workTypeId: workType.id,
          workDate: _workDate,
          quantity: quantity,
          status: 'pending',
          attendanceStatus: 'presente',
          startTime: startTime,
          endTime: endTime,
          restMinutes: restMinutes,
          note: note,
        ),
      );
    }

    if (drafts.isEmpty) {
      _showMessage('Llena al menos una casilla de ${employee.fullName}.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(operatorEntriesRepositoryProvider).createMany(drafts);
      ref.invalidate(operatorEntriesProvider);
      if (!mounted) return;
      _clearAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${employee.fullName}: ${drafts.length} lineas enviadas.')),
      );
      context.go('/operator/entries');
    } catch (error) {
      _showMessage('No se pudo guardar la planilla: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _parseQuantity(String value) {
    final text = value.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void _clearEmployee(String employeeId) {
    setState(() {
      for (final entry in _quantityControllers.entries) {
        if (entry.key.startsWith('$employeeId:')) entry.value.clear();
      }
      _noteControllers[employeeId]?.clear();
      _startTimes.remove(employeeId);
      _endTimes.remove(employeeId);
    });
  }

  void _clearAll() {
    for (final controller in _quantityControllers.values) {
      controller.clear();
    }
    for (final controller in _noteControllers.values) {
      controller.clear();
    }
    _startTimes.clear();
    _endTimes.clear();
  }

  double? _grossWorkedHours(String employeeId) {
    final startTime = _startTimes[employeeId];
    final endTime = _endTimes[employeeId];
    if (startTime == null || endTime == null) return null;
    final start = startTime.hour * 60 + startTime.minute;
    var end = endTime.hour * 60 + endTime.minute;
    if (end < start) end += 24 * 60;
    final minutes = end - start;
    if (minutes <= 0) return null;
    return minutes / 60;
  }

  int _automaticRestMinutes(String employeeId) {
    final grossHours = _grossWorkedHours(employeeId);
    if (grossHours == null) return 0;
    return grossHours > 7 ? 30 : 0;
  }

  TimeOfDayParts? _toParts(TimeOfDay? time) {
    if (time == null) return null;
    return TimeOfDayParts(time.hour, time.minute);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.date,
    required this.onPickDate,
  });

  final String date;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
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
                    'Planilla diaria',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca una casilla, escribe la cantidad y guarda todo junto.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(date),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeePicker extends StatelessWidget {
  const _EmployeePicker({
    required this.employees,
    required this.employeeId,
    required this.onChanged,
  });

  final List<Employee> employees;
  final String? employeeId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DropdownButtonFormField<String>(
          initialValue: employeeId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Trabajador',
            helperText: 'Elige uno para llenar sus trabajos asignados.',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: [
            for (final employee in employees)
              DropdownMenuItem(
                value: employee.id,
                child: Text(
                  '${employee.code} - ${employee.fullName}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EmployeeSheetSection extends StatelessWidget {
  const _EmployeeSheetSection({
    required this.employee,
    required this.workTypes,
    required this.quantityController,
    required this.noteController,
    required this.startTime,
    required this.endTime,
    required this.restMinutes,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClear,
  });

  final Employee employee;
  final List<WorkType> workTypes;
  final TextEditingController Function(String workTypeId) quantityController;
  final TextEditingController noteController;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final int restMinutes;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initials(employee.fullName))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${employee.code} - ${employee.fullName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Limpiar trabajador',
                  onPressed: onClear,
                  icon: const Icon(Icons.cleaning_services_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (workTypes.isEmpty)
              Text(
                'Sin trabajos permitidos.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              for (final workType in workTypes) ...[
                _WorkQuantityField(
                  workType: workType,
                  controller: quantityController(workType.id),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickStart,
                    icon: const Icon(Icons.login_outlined),
                    label: Text(
                      startTime == null
                          ? 'Entrada'
                          : startTime!.format(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickEnd,
                    icon: const Icon(Icons.logout_outlined),
                    label: Text(
                      endTime == null ? 'Salida' : endTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            if (restMinutes > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Descanso automatico: $restMinutes min',
                style: TextStyle(color: colorScheme.primary),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nota opcional',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _WorkQuantityField extends StatelessWidget {
  const _WorkQuantityField({
    required this.workType,
    required this.controller,
  });

  final WorkType workType;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            workType.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 132,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: _unitLabel(workType.unit),
            ),
            onTap: () => controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            ),
          ),
        ),
      ],
    );
  }

  String _unitLabel(String unit) {
    return switch (unit) {
      'hour' => 'h',
      'unit' => 'u',
      'service' => 's',
      'bag' => 'b',
      'bucket' => 't',
      'tray' => 'bd',
      _ => unit,
    };
  }
}

class _SimpleNotice extends StatelessWidget {
  const _SimpleNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
