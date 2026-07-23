import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import 'work_entry.dart';

final workEntriesRepositoryProvider = Provider<WorkEntriesRepository>((ref) {
  return WorkEntriesRepository(ref.watch(supabaseClientProvider));
});

final workEntriesProvider = FutureProvider<List<WorkEntry>>((ref) {
  return ref.watch(workEntriesRepositoryProvider).list();
});

class WorkEntriesRepository {
  WorkEntriesRepository(this._client);

  final SupabaseClient _client;

  Future<List<WorkEntry>> list() async {
    final empresaId = await _empresaId();
    final rows = await _client
        .from('work_entries')
        .select(
            'id, work_date, quantity, status, note, employees(full_name), work_types(name, unit)')
        .eq('empresa_id', empresaId)
        .order('work_date', ascending: false)
        .limit(100);
    return [for (final row in rows) WorkEntry.fromMap(row)];
  }

  Future<void> updateStatus(String id, String status, {String? reason}) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('work_entries').update({
      'status': status,
      'revisado_por': userId,
      'fecha_revision': DateTime.now().toIso8601String(),
      'motivo_rechazo':
          reason == null || reason.trim().isEmpty ? null : reason.trim(),
      'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> updateDetails({
    required String id,
    required double quantity,
    String? note,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('work_entries').update({
      'quantity': quantity,
      'horas_normales': quantity,
      'note': note == null || note.trim().isEmpty ? null : note.trim(),
      'status': 'corrected',
      'revisado_por': userId,
      'fecha_revision': DateTime.now().toIso8601String(),
      'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    }).eq('id', id);
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
