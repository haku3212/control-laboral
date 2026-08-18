import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import 'employee.dart';

final employeesRepositoryProvider = Provider<EmployeesRepository>((ref) {
  return EmployeesRepository(ref.watch(supabaseClientProvider));
});

final employeesProvider = FutureProvider<List<Employee>>((ref) {
  return ref.watch(employeesRepositoryProvider).list();
});

final employeeAllowedWorkTypeIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, employeeId) {
  return ref.watch(employeesRepositoryProvider).allowedWorkTypeIds(employeeId);
});

final employeeAllowedWorkTypeIdsMapProvider =
    FutureProvider<Map<String, Set<String>>>((ref) {
  return ref.watch(employeesRepositoryProvider).allowedWorkTypeIdsMap();
});

class EmployeesRepository {
  EmployeesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Employee>> list() async {
    final empresaId = await _empresaId();
    final rows = await _client
        .from('employees')
        .select()
        .eq('empresa_id', empresaId)
        .isFilter('deleted_at', null)
        .order('active', ascending: false)
        .order('code')
        .order('full_name');
    final employees = [for (final row in rows) Employee.fromMap(row)];
    employees.sort(_compareByCode);
    return employees;
  }

  Future<String> save({
    String? id,
    required String code,
    required String fullName,
    String? documentNumber,
    String? phone,
    String? jobTitle,
    String? notes,
    bool active = true,
    bool restrictWorkTypes = false,
  }) async {
    final empresaId = await _empresaId();
    final userId = _client.auth.currentUser?.id;

    final payload = {
      'empresa_id': empresaId,
      'code': code.trim(),
      'full_name': fullName.trim(),
      'document_number': _blankToNull(documentNumber),
      'phone': _blankToNull(phone),
      'job_title': _blankToNull(jobTitle),
      'notes': _blankToNull(notes),
      'active': active,
      'restrict_work_types': restrictWorkTypes,
      if (id == null && userId != null) 'creado_por': userId,
      if (userId != null) 'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    };

    if (id == null) {
      final row =
          await _client.from('employees').insert(payload).select('id').single();
      return row['id'] as String;
    } else {
      await _client.from('employees').update(payload).eq('id', id);
      return id;
    }
  }

  Future<Employee> saveReturning({
    required String code,
    required String fullName,
    String? documentNumber,
    String? phone,
    String? jobTitle,
    String? notes,
    bool active = true,
    bool restrictWorkTypes = false,
  }) async {
    final empresaId = await _empresaId();
    final userId = _client.auth.currentUser?.id;

    final payload = {
      'empresa_id': empresaId,
      'code': code.trim(),
      'full_name': fullName.trim(),
      'document_number': _blankToNull(documentNumber),
      'phone': _blankToNull(phone),
      'job_title': _blankToNull(jobTitle),
      'notes': _blankToNull(notes),
      'active': active,
      'restrict_work_types': restrictWorkTypes,
      if (userId != null) 'creado_por': userId,
      if (userId != null) 'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    };

    final existing = await _client
        .from('employees')
        .select()
        .eq('empresa_id', empresaId)
        .eq('code', code.trim())
        .maybeSingle();

    if (existing != null) {
      return Employee.fromMap(existing);
    }

    final row =
        await _client.from('employees').insert(payload).select().single();

    return Employee.fromMap(row);
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from('employees').update({
      'active': active,
      'modificado_por': _client.auth.currentUser?.id,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<EmployeeDeleteResult> delete(String id) async {
    final empresaId = await _empresaId();
    final hasHistory = await _hasWorkEntries(empresaId: empresaId, id: id);

    await _client
        .from('employee_work_types')
        .delete()
        .eq('empresa_id', empresaId)
        .eq('employee_id', id);
    await _client
        .from('rates')
        .delete()
        .eq('empresa_id', empresaId)
        .eq('employee_id', id);

    if (hasHistory) {
      await _client
          .from('employees')
          .update({
            'active': false,
            'deleted_at': DateTime.now().toIso8601String(),
            'modificado_por': _client.auth.currentUser?.id,
            'fecha_modificacion': DateTime.now().toIso8601String(),
          })
          .eq('empresa_id', empresaId)
          .eq('id', id);
      return EmployeeDeleteResult.hiddenWithHistory;
    }

    await _client.from('employees').delete().eq('empresa_id', empresaId).eq(
          'id',
          id,
        );
    return EmployeeDeleteResult.deleted;
  }

  Future<bool> _hasWorkEntries({
    required String empresaId,
    required String id,
  }) async {
    final rows = await _client
        .from('work_entries')
        .select('id')
        .eq('empresa_id', empresaId)
        .eq('employee_id', id)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<Set<String>> allowedWorkTypeIds(String employeeId) async {
    final empresaId = await _empresaId();
    final rows = await _client
        .from('employee_work_types')
        .select('work_type_id')
        .eq('empresa_id', empresaId)
        .eq('employee_id', employeeId);
    return {
      for (final row in rows) row['work_type_id'] as String,
    };
  }

  Future<Map<String, Set<String>>> allowedWorkTypeIdsMap() async {
    final empresaId = await _empresaId();
    final rows = await _client
        .from('employee_work_types')
        .select('employee_id, work_type_id')
        .eq('empresa_id', empresaId);
    final map = <String, Set<String>>{};
    for (final row in rows) {
      final employeeId = row['employee_id'] as String;
      final workTypeId = row['work_type_id'] as String;
      map.putIfAbsent(employeeId, () => <String>{}).add(workTypeId);
    }
    return map;
  }

  Future<void> saveWorkTypePermissions({
    required String employeeId,
    required bool restrictWorkTypes,
    required Set<String> workTypeIds,
  }) async {
    final empresaId = await _empresaId();
    final userId = _client.auth.currentUser?.id;

    await _client.from('employees').update({
      'restrict_work_types': restrictWorkTypes,
      'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    }).eq('id', employeeId);

    await _client
        .from('employee_work_types')
        .delete()
        .eq('empresa_id', empresaId)
        .eq('employee_id', employeeId);

    if (!restrictWorkTypes || workTypeIds.isEmpty) return;

    await _client.from('employee_work_types').insert([
      for (final workTypeId in workTypeIds)
        {
          'empresa_id': empresaId,
          'employee_id': employeeId,
          'work_type_id': workTypeId,
          if (userId != null) 'creado_por': userId,
        },
    ]);
  }

  Future<String> _empresaId() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('Sesión no iniciada.');
    }

    final row = await _client
        .from('profiles')
        .select('empresa_id')
        .eq('id', userId)
        .single();

    final empresaId = row['empresa_id'] as String?;

    if (empresaId == null || empresaId.isEmpty) {
      throw StateError('Tu usuario no tiene empresa asignada.');
    }

    return empresaId;
  }

  String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  int _compareByCode(Employee a, Employee b) {
    if (a.active != b.active) return a.active ? -1 : 1;

    final numberA = int.tryParse(a.code.trim());
    final numberB = int.tryParse(b.code.trim());
    if (numberA != null && numberB != null && numberA != numberB) {
      return numberA.compareTo(numberB);
    }

    final codeCompare = a.code.compareTo(b.code);
    if (codeCompare != 0) return codeCompare;
    return a.fullName.compareTo(b.fullName);
  }
}

enum EmployeeDeleteResult {
  deleted,
  hiddenWithHistory,
}
