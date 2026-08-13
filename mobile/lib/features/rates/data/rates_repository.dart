import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import 'rate.dart';

final ratesRepositoryProvider = Provider<RatesRepository>((ref) {
  return RatesRepository(ref.watch(supabaseClientProvider));
});

final ratesProvider = FutureProvider<List<Rate>>((ref) {
  return ref.watch(ratesRepositoryProvider).list();
});

class RatesRepository {
  RatesRepository(this._client);

  final SupabaseClient _client;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<Rate>> list() async {
    final empresaId = await _empresaId();
    final rows = await _client
        .from('rates')
        .select('*, work_types(name), employees(full_name)')
        .eq('empresa_id', empresaId)
        .order('active', ascending: false)
        .order('valid_from', ascending: false);
    return [for (final row in rows) Rate.fromMap(row)];
  }

  Future<void> save({
    String? id,
    required String workTypeId,
    required String? employeeId,
    required double unitPrice,
    required DateTime validFrom,
    required DateTime? validUntil,
    required bool active,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final empresaId = await _empresaId();
    final payload = {
      'empresa_id': empresaId,
      'work_type_id': workTypeId,
      'employee_id': employeeId,
      'unit_price': unitPrice,
      'valid_from': _dateFormat.format(validFrom),
      'valid_until': validUntil == null ? null : _dateFormat.format(validUntil),
      'active': active,
      if (id == null && userId != null) 'created_by': userId,
      if (userId != null) 'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    };

    if (id == null) {
      await _client.from('rates').insert(payload);
    } else {
      await _client.from('rates').update(payload).eq('id', id);
    }
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
