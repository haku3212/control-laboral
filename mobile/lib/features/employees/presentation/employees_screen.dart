import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../work_types/data/work_type.dart';
import '../../work_types/data/work_types_repository.dart';
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
    final currentEmployees = employees.valueOrNull ?? const <Employee>[];

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar trabajador',
                    hintText: 'Nombre, código, CI o teléfono',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() => _query = value.toLowerCase().trim());
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _importFromExcel(currentEmployees),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Importar trabajadores desde Excel'),
                ),
              ],
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
                      (employee.phone ?? '').toLowerCase().contains(_query) ||
                      (employee.jobTitle ?? '').toLowerCase().contains(_query);
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
                                        '${employee.code} - ${employee.fullName}',
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
                                        text:
                                            'Código de pago: ${employee.code}',
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
                                      _EmployeeInfoLine(
                                        icon: Icons.rule_folder_outlined,
                                        text: employee.restrictWorkTypes
                                            ? 'Trabajos limitados'
                                            : 'Todos los trabajos habilitados',
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

  Future<void> _importFromExcel(List<Employee> existingEmployees) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;

    try {
      final rows = _parseEmployeeRows(bytes, existingEmployees);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _EmployeeImportPreviewDialog(rows: rows),
      );
      if (confirmed != true) return;

      final validRows = rows.where((row) => row.canImport).toList();
      if (validRows.isEmpty) {
        _showMessage('No hay trabajadores validos para importar.');
        return;
      }

      for (final row in validRows) {
        await ref.read(employeesRepositoryProvider).saveReturning(
              code: row.code,
              fullName: row.fullName,
              documentNumber: row.documentNumber,
              phone: row.phone,
              jobTitle: row.jobTitle,
              active: true,
            );
      }

      ref.invalidate(employeesProvider);
      _showMessage('Importados: ${validRows.length} trabajadores.');
    } catch (error) {
      _showMessage('No se pudo leer el Excel: $error');
    }
  }

  List<_EmployeeImportRow> _parseEmployeeRows(
    List<int> bytes,
    List<Employee> existingEmployees,
  ) {
    final excel = xl.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) return [];

    final headers = [
      for (final cell in sheet.rows.first) _cellText(cell).toLowerCase(),
    ];
    final codeIndex = _findHeader(headers, ['codigo', 'código', 'code']);
    final nameIndex = _findHeader(headers, ['nombre', 'trabajador', 'name']);
    final ciIndex = _findHeader(headers, ['ci', 'documento', 'cedula']);
    final phoneIndex =
        _findHeader(headers, ['telefono', 'teléfono', 'celular']);
    final jobIndex = _findHeader(headers, ['cargo', 'puesto']);

    if (codeIndex == -1 || nameIndex == -1) {
      throw StateError('El Excel debe tener columnas codigo y nombre.');
    }

    final existingCodes = {
      for (final item in existingEmployees) item.code.trim().toUpperCase(),
    };
    final seenCodes = <String>{};
    final parsed = <_EmployeeImportRow>[];

    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];
      final code = _cellAt(row, codeIndex).toUpperCase();
      final name = _cellAt(row, nameIndex);
      final document = ciIndex == -1 ? '' : _cellAt(row, ciIndex);
      final phone = phoneIndex == -1 ? '' : _cellAt(row, phoneIndex);
      final job = jobIndex == -1 ? '' : _cellAt(row, jobIndex);

      if (code.isEmpty && name.isEmpty) continue;

      String? error;
      if (code.isEmpty) {
        error = 'Falta codigo';
      } else if (name.isEmpty) {
        error = 'Falta nombre';
      } else if (existingCodes.contains(code)) {
        error = 'Codigo ya existe';
      } else if (!seenCodes.add(code)) {
        error = 'Codigo repetido en Excel';
      }

      parsed.add(
        _EmployeeImportRow(
          rowNumber: rowIndex + 1,
          code: code,
          fullName: name,
          documentNumber: document,
          phone: phone,
          jobTitle: job,
          error: error,
        ),
      );
    }

    return parsed;
  }

  int _findHeader(List<String> headers, List<String> names) {
    for (var index = 0; index < headers.length; index++) {
      final header = headers[index].trim();
      if (names.any((name) => header == name || header.contains(name))) {
        return index;
      }
    }
    return -1;
  }

  String _cellAt(List<xl.Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return _cellText(row[index]);
  }

  String _cellText(xl.Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    try {
      final dynamic dynamicValue = value;
      return '${dynamicValue.value}'.trim();
    } catch (_) {
      return '$value'.trim();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

class _EmployeeImportRow {
  const _EmployeeImportRow({
    required this.rowNumber,
    required this.code,
    required this.fullName,
    required this.documentNumber,
    required this.phone,
    required this.jobTitle,
    required this.error,
  });

  final int rowNumber;
  final String code;
  final String fullName;
  final String documentNumber;
  final String phone;
  final String jobTitle;
  final String? error;

  bool get canImport => error == null;
}

class _EmployeeImportPreviewDialog extends StatelessWidget {
  const _EmployeeImportPreviewDialog({required this.rows});

  final List<_EmployeeImportRow> rows;

  @override
  Widget build(BuildContext context) {
    final validCount = rows.where((row) => row.canImport).length;
    final errorCount = rows.length - validCount;

    return AlertDialog(
      title: const Text('Vista previa de importacion'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Listos: $validCount   Con error: $errorCount'),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      row.canImport
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: row.canImport
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    title: Text('${row.code} - ${row.fullName}'),
                    subtitle: Text(
                      row.canImport
                          ? 'Fila ${row.rowNumber}'
                          : 'Fila ${row.rowNumber}: ${row.error}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed:
              validCount == 0 ? null : () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.save_outlined),
          label: Text('Importar $validCount'),
        ),
      ],
    );
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
  late bool _restrictWorkTypes;
  final Set<String> _allowedWorkTypeIds = {};
  bool _loadingPermissions = false;
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
    _restrictWorkTypes = employee?.restrictWorkTypes ?? false;

    if (employee != null) {
      _loadPermissions(employee.id);
    }
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
    final workTypes = ref.watch(workTypesProvider);

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
                  hintText: 'Ej: 01, 02, 03',
                  helperText: 'Se usará para ordenar planillas y pagos.',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: _codeValidator,
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
              const SizedBox(height: 8),
              Text(
                'Trabajos permitidos',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _restrictWorkTypes,
                title: const Text('Limitar trabajos para este trabajador'),
                subtitle: Text(
                  _restrictWorkTypes
                      ? 'El encargado solo vera los trabajos marcados.'
                      : 'El encargado podra elegir cualquier trabajo activo.',
                ),
                onChanged: (value) {
                  setState(() => _restrictWorkTypes = value);
                },
              ),
              if (_restrictWorkTypes) ...[
                const SizedBox(height: 4),
                if (_loadingPermissions)
                  const LinearProgressIndicator()
                else
                  workTypes.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) =>
                        Text('No se cargaron trabajos: $error'),
                    data: (items) => _AllowedWorkTypesPicker(
                      items: items.where((item) => item.active).toList(),
                      selectedIds: _allowedWorkTypeIds,
                      onChanged: (workTypeId, selected) {
                        setState(() {
                          if (selected) {
                            _allowedWorkTypeIds.add(workTypeId);
                          } else {
                            _allowedWorkTypeIds.remove(workTypeId);
                          }
                        });
                      },
                    ),
                  ),
              ],
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

  String? _codeValidator(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return 'Ingresa el código de pago';
    if (text.contains(RegExp(r'\s'))) {
      return 'El código no debe tener espacios';
    }
    return null;
  }

  Future<void> _loadPermissions(String employeeId) async {
    setState(() => _loadingPermissions = true);
    try {
      final ids = await ref
          .read(employeesRepositoryProvider)
          .allowedWorkTypeIds(employeeId);
      if (!mounted) return;
      setState(() {
        _allowedWorkTypeIds
          ..clear()
          ..addAll(ids);
      });
    } finally {
      if (mounted) setState(() => _loadingPermissions = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final employeeId = await ref.read(employeesRepositoryProvider).save(
            id: widget.employee?.id,
            code: _normalizeCode(_code.text),
            fullName: _name.text,
            documentNumber: _document.text,
            phone: _phone.text,
            jobTitle: _jobTitle.text,
            notes: _notes.text,
            active: _active,
            restrictWorkTypes: _restrictWorkTypes,
          );
      await ref.read(employeesRepositoryProvider).saveWorkTypePermissions(
            employeeId: employeeId,
            restrictWorkTypes: _restrictWorkTypes,
            workTypeIds: _allowedWorkTypeIds,
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

  String _normalizeCode(String value) => value.trim().toUpperCase();
}

class _AllowedWorkTypesPicker extends StatelessWidget {
  const _AllowedWorkTypesPicker({
    required this.items,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<WorkType> items;
  final Set<String> selectedIds;
  final void Function(String workTypeId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No hay trabajos activos para asignar.');
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final item in items)
            CheckboxListTile(
              dense: true,
              value: selectedIds.contains(item.id),
              title: Text(item.name),
              subtitle: Text(_unitLabel(item.unit)),
              onChanged: (value) => onChanged(item.id, value ?? false),
            ),
        ],
      ),
    );
  }
}

String _unitLabel(String value) {
  return switch (value) {
    'hour' => 'Horas',
    'unit' => 'Unidades',
    'service' => 'Servicios',
    'bag' => 'Bolsas',
    'bucket' => 'Tachos',
    'tray' => 'Bandejas',
    _ => value,
  };
}
