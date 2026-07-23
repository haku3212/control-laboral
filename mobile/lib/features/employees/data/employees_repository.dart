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

class EmployeesRepository {
  EmployeesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Employee>> list() async {
    final empresaId = await _empresaId();
    final rows = await _client
        .from('employees')
        .select()
        .eq('empresa_id', empresaId)
        .order('active', ascending: false)
        .order('full_name');
    return [for (final row in rows) Employee.fromMap(row)];
  }

  Future<void> save({
    String? id,
    required String code,
    required String fullName,
    String? documentNumber,
    String? phone,
    String? jobTitle,
    String? notes,
    bool active = true,
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
      if (id == null && userId != null) 'creado_por': userId,
      if (userId != null) 'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    };

    if (id == null) {
      await _client.from('employees').insert(payload);
    } else {
      await _client.from('employees').update(payload).eq('id', id);
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

  Future<String> _empresaId() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('Sesion no iniciada.');
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
}