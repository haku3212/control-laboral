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
    final rows = await _client
        .from('work_entries')
        .select('id, work_date, quantity, status, note, employees(full_name), work_types(name, unit)')
        .order('work_date', ascending: false)
        .limit(100);
    return [for (final row in rows) WorkEntry.fromMap(row)];
  }

  Future<void> updateStatus(String id, String status) async {
    await _client.from('work_entries').update({'status': status}).eq('id', id);
  }

  Future<void> updateDetails({
    required String id,
    required double quantity,
    String? note,
  }) async {
    await _client.from('work_entries').update({
      'quantity': quantity,
      'note': note == null || note.trim().isEmpty ? null : note.trim(),
      'status': 'corrected',
    }).eq('id', id);
  }
}
