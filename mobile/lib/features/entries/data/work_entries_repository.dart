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

final workEntriesByDateProvider =
    FutureProvider.family<List<WorkEntry>, DateTime>((ref, date) {
  return ref.watch(workEntriesRepositoryProvider).list(workDate: date);
});

final workEntriesByRangeProvider = FutureProvider.family<
    List<WorkEntry>, ({DateTime startDate, DateTime endDate})>((ref, range) {
  return ref.watch(workEntriesRepositoryProvider).list(
        startDate: range.startDate,
        endDate: range.endDate,
      );
});

class WorkEntriesRepository {
  WorkEntriesRepository(this._client);

  final SupabaseClient _client;

  Future<List<WorkEntry>> list({
    DateTime? workDate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final empresaId = await _empresaId();
    var query = _client
        .from('work_entries')
        .select(
            'id, work_date, quantity, status, note, employees(code, full_name), work_types(name, unit)')
        .eq('empresa_id', empresaId);

    if (workDate != null) {
      final dateText = _dateText(workDate);
      query = query.eq('work_date', dateText);
    } else {
      if (startDate != null) {
        query = query.gte('work_date', _dateText(startDate));
      }
      if (endDate != null) {
        query = query.lte('work_date', _dateText(endDate));
      }
    }

    final rows = await query.order('work_date', ascending: false).limit(100);
    return [for (final row in rows) WorkEntry.fromMap(row)];
  }

  String _dateText(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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

  Future<void> updateStatuses(
    List<String> ids,
    String status, {
    String? reason,
  }) async {
    if (ids.isEmpty) return;
    final userId = _client.auth.currentUser?.id;
    await _client.from('work_entries').update({
      'status': status,
      'revisado_por': userId,
      'fecha_revision': DateTime.now().toIso8601String(),
      'motivo_rechazo':
          reason == null || reason.trim().isEmpty ? null : reason.trim(),
      'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    }).inFilter('id', ids);
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
    if (userId == null) throw StateError('Sesión no iniciada.');
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
