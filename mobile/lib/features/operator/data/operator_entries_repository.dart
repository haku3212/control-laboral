import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/profile_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'operator_entry.dart';

final operatorEntriesRepositoryProvider =
    Provider<OperatorEntriesRepository>((ref) {
  return OperatorEntriesRepository(ref.watch(supabaseClientProvider));
});

final operatorEntriesProvider =
    FutureProvider<List<OperatorEntry>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(operatorEntriesRepositoryProvider).list();
});

class OperatorEntriesRepository {
  OperatorEntriesRepository(this._client);

  final SupabaseClient _client;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<OperatorEntry>> list() async {
    final empresaId = await _empresaId();
    final rows = await _client
        .from('work_entries')
        .select(
            'id, work_date, quantity, status, note, employees(full_name), work_types(name, unit)')
        .eq('empresa_id', empresaId)
        .eq('registered_by', _client.auth.currentUser!.id)
        .order('work_date', ascending: false)
        .limit(50);
    return [for (final row in rows) OperatorEntry.fromMap(row)];
  }

  Future<void> create({
    required String employeeId,
    required String workTypeId,
    required DateTime workDate,
    required double quantity,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final empresaId = await _empresaId();
    await _client.from('work_entries').insert({
      'empresa_id': empresaId,
      'employee_id': employeeId,
      'work_type_id': workTypeId,
      'work_date': _dateFormat.format(workDate),
      'quantity': quantity,
      'horas_normales': quantity,
      'note': _blankToNull(note),
      'source': 'app',
      'status': 'draft',
      'registered_by': userId,
      'creado_por': userId,
      'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    });
  }

  String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<String> _empresaId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sesion no iniciada.');
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
}
