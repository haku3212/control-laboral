import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/profile_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'operator_entry.dart';

final operatorEntriesRepositoryProvider = Provider<OperatorEntriesRepository>((ref) {
  return OperatorEntriesRepository(ref.watch(supabaseClientProvider));
});

final operatorEntriesProvider = FutureProvider<List<OperatorEntry>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(operatorEntriesRepositoryProvider).list();
});

class OperatorEntriesRepository {
  OperatorEntriesRepository(this._client);

  final SupabaseClient _client;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<OperatorEntry>> list() async {
    final rows = await _client
        .from('work_entries')
        .select('id, work_date, quantity, status, note, employees(full_name), work_types(name, unit)')
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
    await _client.from('work_entries').insert({
      'employee_id': employeeId,
      'work_type_id': workTypeId,
      'work_date': _dateFormat.format(workDate),
      'quantity': quantity,
      'note': _blankToNull(note),
      'source': 'app',
      'status': 'draft',
      'registered_by': userId,
    });
  }

  String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
