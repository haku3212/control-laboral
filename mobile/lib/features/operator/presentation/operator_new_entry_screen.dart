import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/profile_provider.dart';
import '../../../shared/widgets/section_card.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _overtime = TextEditingController(text: '0');
  final _note = TextEditingController();
  final _inlineEmployee = TextEditingController();
  final _inlineWorkType = TextEditingController();
  String? _employeeId;
  String? _workTypeId;
  String _attendanceStatus = 'presente';
  DateTime _workDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _overtime.dispose();
    _note.dispose();
    _inlineEmployee.dispose();
    _inlineWorkType.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workTypes = ref.watch(workTypesProvider);
    final employees = ref.watch(employeesProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ScreenHeader(workDate: _workDate, onPickDate: _pickDate),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle(
                  icon: Icons.groups_outlined,
                  title: 'Trabajador y trabajo',
                ),
                const SizedBox(height: 12),
                employees.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      Text('No se cargaron trabajadores: $error'),
                  data: (items) =>
                      _employeeDropdown(items.where((e) => e.active).toList()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inlineEmployee,
                  decoration: const InputDecoration(
                    labelText: 'Escribir trabajador rápido',
                    hintText: 'Si no está en la lista',
                    prefixIcon: Icon(Icons.person_add_alt),
                  ),
                  onChanged: (value) {
                    if (value.trim().isNotEmpty && _employeeId != null) {
                      setState(() => _employeeId = null);
                    }
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _createEmployee,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Agregar trabajador con datos'),
                  ),
                ),
                const SizedBox(height: 8),
                workTypes.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) =>
                      Text('No se cargaron tipos de trabajo: $error'),
                  data: (items) =>
                      _workTypeDropdown(items.where((e) => e.active).toList()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inlineWorkType,
                  decoration: const InputDecoration(
                    labelText: 'Escribir trabajo rápido',
                    hintText: 'Ej: Fundir silicato',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                  ),
                  onChanged: (value) {
                    if (value.trim().isNotEmpty && _workTypeId != null) {
                      setState(() => _workTypeId = null);
                    }
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _createWorkType,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Agregar trabajo con unidad'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle(
                  icon: Icons.schedule_outlined,
                  title: 'Asistencia y horas',
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'presente',
                      label: Text('Presente'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: 'falta_justificada',
                      label: Text('Justificada'),
                      icon: Icon(Icons.event_available_outlined),
                    ),
                    ButtonSegment(
                      value: 'falta_injustificada',
                      label: Text('Falta'),
                      icon: Icon(Icons.cancel_outlined),
                    ),
                  ],
                  selected: {_attendanceStatus},
                  onSelectionChanged: (value) {
                    setState(() => _attendanceStatus = value.first);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(isStart: true),
                        icon: const Icon(Icons.login_outlined),
                        label: Text(_startTime == null
                            ? 'Entrada'
                            : _startTime!.format(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickTime(isStart: false),
                        icon: const Icon(Icons.logout_outlined),
                        label: Text(_endTime == null
                            ? 'Salida'
                            : _endTime!.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AutoBreakNotice(
                  restMinutes: _automaticRestMinutes(),
                  grossHours: _grossWorkedHours(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _overtime,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Horas extra',
                    suffixText: 'h',
                    prefixIcon: Icon(Icons.more_time_outlined),
                  ),
                  validator: (value) {
                    final parsed =
                        double.tryParse(value?.replaceAll(',', '.') ?? '0');
                    if (parsed == null || parsed < 0) return 'Inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Horas normales o cantidad',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (value) {
                    if (_attendanceStatus != 'presente') return null;
                    final parsed =
                        double.tryParse(value?.replaceAll(',', '.') ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Ingresa una cantidad válida';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle(
                  icon: Icons.notes_outlined,
                  title: 'Notas',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Notas del trabajo',
                    hintText:
                        'Ej: trabajo en cisterna grande, llegó tarde, faltaron bolsas',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_saving ? 'Guardando...' : 'Enviar al gerente'),
          ),
        ],
      ),
    );
  }

  Widget _workTypeDropdown(List<WorkType> items) {
    return DropdownButtonFormField<String>(
      initialValue: _workTypeId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tipo de trabajo',
        prefixIcon: Icon(Icons.work_outline),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item.id,
            child: Text(
              '${item.name} (${_unitLabel(item.unit)})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => setState(() => _workTypeId = value),
    );
  }

  Widget _employeeDropdown(List<Employee> items) {
    return DropdownButtonFormField<String>(
      initialValue: _employeeId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Trabajador',
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item.id,
            child: Text(
              '${item.code} - ${item.fullName}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
    if (!mounted || picked == null) return;
    setState(() => _workDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      final calculated = _calculatedNormalHours();
      if (calculated != null) {
        _quantity.text = calculated.toStringAsFixed(2);
      }
    });
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
            quantity: _attendanceStatus == 'presente'
                ? double.parse(_quantity.text.replaceAll(',', '.'))
                : 0,
            status: 'pending',
            attendanceStatus: _attendanceStatus,
            startTime: _toParts(_startTime),
            endTime: _toParts(_endTime),
            restMinutes: _automaticRestMinutes(),
            overtimeHours:
                double.tryParse(_overtime.text.replaceAll(',', '.')) ?? 0,
            note: _note.text,
          );
      ref.invalidate(operatorEntriesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jornada enviada al gerente.')),
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
    final draft = await _showEmployeeDialog();
    if (draft == null) return;

    try {
      final employee =
          await ref.read(employeesRepositoryProvider).saveReturning(
                code: draft.code,
                fullName: draft.fullName,
                documentNumber: draft.documentNumber,
                phone: draft.phone,
                jobTitle: draft.jobTitle,
                active: true,
              );

      if (!mounted) return;

      setState(() {
        _employeeId = employee.id;
        _inlineEmployee.clear();
      });

      ref.invalidate(employeesProvider);
      await ref.read(employeesProvider.future);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${employee.fullName} fue agregado y seleccionado.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el trabajador: $error')),
      );
    }
  }

  Future<_EmployeeDraft?> _showEmployeeDialog() {
    return showDialog<_EmployeeDraft>(
      context: context,
      builder: (_) => const _EmployeeDialog(),
    );
  }

  Future<void> _createWorkType() async {
    final draft = await showDialog<_WorkTypeDraft>(
      context: context,
      builder: (_) => const _WorkTypeDialog(),
    );

    if (draft == null) return;

    try {
      final workType =
          await ref.read(workTypesRepositoryProvider).saveReturning(
                code: _codeFromName(draft.name),
                name: draft.name,
                unit: draft.unit,
                category: draft.category,
                active: true,
              );

      if (!mounted) return;

      setState(() {
        _workTypeId = workType.id;
        _inlineWorkType.clear();
      });
      ref.invalidate(workTypesProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${workType.name} fue agregado y seleccionado.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear el tipo de trabajo: $error'),
        ),
      );
    }
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
    final row = await ref.read(employeesRepositoryProvider).saveReturning(
          code: _codeFromName(name),
          fullName: name,
        );
    return row.id;
  }

  Future<String> _createWorkTypeFromName(String name) async {
    final row = await ref.read(workTypesRepositoryProvider).saveReturning(
          code: _codeFromName(name),
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
    return code.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : code;
  }

  double? _calculatedNormalHours() {
    final grossHours = _grossWorkedHours();
    if (grossHours == null) return null;
    final minutes = (grossHours * 60).round() - _automaticRestMinutes();
    if (minutes <= 0) return null;
    return minutes / 60;
  }

  double? _grossWorkedHours() {
    if (_startTime == null || _endTime == null) return null;
    final start = _startTime!.hour * 60 + _startTime!.minute;
    var end = _endTime!.hour * 60 + _endTime!.minute;
    if (end < start) end += 24 * 60;
    final minutes = end - start;
    if (minutes <= 0) return null;
    return minutes / 60;
  }

  int _automaticRestMinutes() {
    final grossHours = _grossWorkedHours();
    if (_startTime == null || grossHours == null) return 0;
    final startsInMorning = _startTime!.hour < 12;
    return startsInMorning && grossHours > 7 ? 30 : 0;
  }

  TimeOfDayParts? _toParts(TimeOfDay? time) {
    if (time == null) return null;
    return TimeOfDayParts(time.hour, time.minute);
  }

  String _unitLabel(String unit) {
    return switch (unit) {
      'hour' => 'hora',
      'unit' => 'unidad',
      'service' => 'servicio',
      'bag' => 'bolsa',
      'bucket' => 'tacho',
      'tray' => 'bandeja',
      _ => unit,
    };
  }
}

class _AutoBreakNotice extends StatelessWidget {
  const _AutoBreakNotice({
    required this.restMinutes,
    required this.grossHours,
  });

  final int restMinutes;
  final double? grossHours;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final applied = restMinutes > 0;
    final message = grossHours == null
        ? 'El descanso se calculará cuando ingreses entrada y salida.'
        : applied
            ? 'Se descontarán 30 min automáticamente por turno de mañana mayor a 7 h.'
            : 'Sin descuento automático de descanso para este horario.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: applied
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            applied ? Icons.free_breakfast_outlined : Icons.info_outline,
            color: applied
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: applied
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.workDate,
    required this.onPickDate,
  });

  final DateTime workDate;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'es_BO');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jornada diaria',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                'Registra y envía la jornada al gerente.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onPickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(dateFormat.format(workDate)),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _WorkTypeDialog extends StatefulWidget {
  const _WorkTypeDialog();

  @override
  State<_WorkTypeDialog> createState() => _WorkTypeDialogState();
}

class _WorkTypeDialogState extends State<_WorkTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _unit = 'unit';
  String _category = 'quantity';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _WorkTypeDraft(
        name: _name.text.trim(),
        unit: _unit,
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_business_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('Agregar trabajo')),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del trabajo',
                    hintText: 'Ej: Bolsas de soda',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa el nombre del trabajo'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unidad de pago',
                    prefixIcon: Icon(Icons.straighten_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'hour', child: Text('Hora')),
                    DropdownMenuItem(value: 'unit', child: Text('Unidad')),
                    DropdownMenuItem(value: 'service', child: Text('Servicio')),
                    DropdownMenuItem(value: 'bag', child: Text('Bolsa')),
                    DropdownMenuItem(value: 'bucket', child: Text('Tacho')),
                    DropdownMenuItem(value: 'tray', child: Text('Bandeja')),
                  ],
                  onChanged: (value) => setState(() {
                    _unit = value ?? _unit;
                    _category = _unit == 'hour' ? 'hourly' : 'quantity';
                  }),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'quantity',
                      label: Text('Cantidad'),
                      icon: Icon(Icons.numbers),
                    ),
                    ButtonSegment(
                      value: 'hourly',
                      label: Text('Horas'),
                      icon: Icon(Icons.schedule_outlined),
                    ),
                    ButtonSegment(
                      value: 'attendance',
                      label: Text('Asistencia'),
                      icon: Icon(Icons.event_available_outlined),
                    ),
                  ],
                  selected: {_category},
                  onSelectionChanged: (value) {
                    setState(() => _category = value.first);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _WorkTypeDraft {
  const _WorkTypeDraft({
    required this.name,
    required this.unit,
    required this.category,
  });

  final String name;
  final String unit;
  final String category;
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog();

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _documentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final fullName = _nameController.text.trim();
    final customCode = _codeController.text.trim().toUpperCase();

    Navigator.of(context).pop(
      _EmployeeDraft(
        fullName: fullName,
        code: customCode,
        documentNumber: _documentController.text.trim(),
        phone: _phoneController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add_alt),
          SizedBox(width: 10),
          Expanded(child: Text('Agregar trabajador')),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    hintText: 'Ej: 01, 02, 03',
                    helperText: 'Código usado para planillas y pagos.',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: _codeValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa el nombre completo'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _documentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CI',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _jobTitleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Cargo',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }

  String? _codeValidator(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return 'Ingresa el código de pago';
    if (text.contains(RegExp(r'\s'))) {
      return 'El código no debe tener espacios';
    }
    return null;
  }
}

class _EmployeeDraft {
  const _EmployeeDraft({
    required this.fullName,
    required this.code,
    required this.documentNumber,
    required this.phone,
    required this.jobTitle,
  });

  final String fullName;
  final String code;
  final String documentNumber;
  final String phone;
  final String jobTitle;
}
