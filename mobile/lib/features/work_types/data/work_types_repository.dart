import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import 'work_type.dart';

final workTypesRepositoryProvider = Provider<WorkTypesRepository>((ref) {
  return WorkTypesRepository(ref.watch(supabaseClientProvider));
});

final workTypesProvider = FutureProvider<List<WorkType>>((ref) {
  return ref.watch(workTypesRepositoryProvider).list();
});

class WorkTypesRepository {
  WorkTypesRepository(this._client);

  final SupabaseClient _client;

  Future<List<WorkType>> list() async {
    final empresaId = await _empresaId();
    final rows = await _client
        .from('work_types')
        .select()
        .eq('empresa_id', empresaId)
        .order('active', ascending: false)
        .order('name');
    return [for (final row in rows) WorkType.fromMap(row)];
  }

  Future<void> save({
    String? id,
    required String code,
    required String name,
    required String unit,
    required String category,
    required bool active,
  }) async {
    final empresaId = await _empresaId();
    final userId = _client.auth.currentUser?.id;
    final payload = {
      'empresa_id': empresaId,
      'code': code.trim(),
      'name': name.trim(),
      'unit': unit,
      'category': category,
      'active': active,
      if (id == null && userId != null) 'creado_por': userId,
      if (userId != null) 'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    };

    if (id == null) {
      await _client.from('work_types').insert(payload);
    } else {
      await _client.from('work_types').update(payload).eq('id', id);
    }
  }

  Future<WorkType> saveReturning({
    required String code,
    required String name,
    required String unit,
    required String category,
    required bool active,
  }) async {
    final empresaId = await _empresaId();
    final userId = _client.auth.currentUser?.id;
    final payload = {
      'empresa_id': empresaId,
      'code': code.trim(),
      'name': name.trim(),
      'unit': unit,
      'category': category,
      'active': active,
      if (userId != null) 'creado_por': userId,
      if (userId != null) 'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    };

    final existing = await _client
        .from('work_types')
        .select()
        .eq('empresa_id', empresaId)
        .eq('code', code.trim())
        .maybeSingle();
    if (existing != null) return WorkType.fromMap(existing);

    final row =
        await _client.from('work_types').insert(payload).select().single();
    return WorkType.fromMap(row);
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
