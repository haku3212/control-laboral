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
    final rows = await _client
        .from('employees')
        .select()
        .order('active', ascending: false)
        .order('full_name');
    return [for (final row in rows) Employee.fromMap(row)];
  }

  Future<void> save({
    String? id,
    required String code,
    required String fullName,
    String? documentNumber,
    String? jobTitle,
    String? notes,
    bool active = true,
  }) async {
    final payload = {
      'code': code.trim(),
      'full_name': fullName.trim(),
      'document_number': _blankToNull(documentNumber),
      'job_title': _blankToNull(jobTitle),
      'notes': _blankToNull(notes),
      'active': active,
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
    String? jobTitle,
    String? notes,
    bool active = true,
  }) async {
    final payload = {
      'code': code.trim(),
      'full_name': fullName.trim(),
      'document_number': _blankToNull(documentNumber),
      'job_title': _blankToNull(jobTitle),
      'notes': _blankToNull(notes),
      'active': active,
    };

    final existing = await _client
        .from('employees')
        .select()
        .eq('code', code.trim())
        .maybeSingle();
    if (existing != null) return Employee.fromMap(existing);

    final row = await _client
        .from('employees')
        .insert(payload)
        .select()
        .single();
    return Employee.fromMap(row);
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from('employees').update({'active': active}).eq('id', id);
  }

  String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
