import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import 'payroll_summary.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository(ref.watch(supabaseClientProvider));
});

final payrollSummariesProvider =
    FutureProvider<List<EmployeePayrollSummary>>((ref) async {
  return ref.watch(payrollRepositoryProvider).summaries();
});

class PayrollRepository {
  PayrollRepository(this._client);

  final SupabaseClient _client;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<EmployeePayrollSummary>> summaries() async {
    final empresaId = await _empresaId();
    final period = await _currentPeriod();
    final entries = await _client
        .from('work_entries')
        .select(
          'id, employee_id, work_type_id, work_date, quantity, employees(full_name), work_types(name, unit)',
        )
        .eq('empresa_id', empresaId)
        .eq('status', 'confirmed')
        .gte('work_date', period['start_date'])
        .lte('work_date', period['end_date'])
        .order('work_date', ascending: false);

    final rates = await _client
        .from('rates')
        .select(
            'work_type_id, employee_id, unit_price, valid_from, valid_until, active')
        .eq('empresa_id', empresaId)
        .eq('active', true)
        .order('valid_from', ascending: false);

    final lines = <PayrollLine>[];
    for (final entry in entries) {
      final employeeId = entry['employee_id'] as String;
      final workTypeId = entry['work_type_id'] as String;
      final workDate = DateTime.parse(entry['work_date'] as String);
      lines.add(
        PayrollLine(
          entryId: entry['id'] as String,
          employeeId: employeeId,
          employeeName: entry['employees']['full_name'] as String,
          workTypeId: workTypeId,
          workTypeName: entry['work_types']['name'] as String,
          unit: entry['work_types']['unit'] as String,
          quantity: double.parse('${entry['quantity']}'),
          workDate: workDate,
          rate: _findRate(
            rates: rates,
            employeeId: employeeId,
            workTypeId: workTypeId,
            workDate: workDate,
          ),
        ),
      );
    }

    final grouped = <String, List<PayrollLine>>{};
    for (final line in lines) {
      grouped.putIfAbsent(line.employeeId, () => []).add(line);
    }

    final payrolls = await _client
        .from('weekly_payrolls')
        .select(
            'id, employee_id, status, payroll_adjustments(id, type, concept, amount)')
        .eq('empresa_id', empresaId)
        .eq('weekly_period_id', period['id']);
    final payrollByEmployee = {
      for (final item in payrolls) item['employee_id'] as String: item,
    };

    return [
      for (final entry in grouped.entries)
        EmployeePayrollSummary(
          employeeId: entry.key,
          employeeName: entry.value.first.employeeName,
          lines: entry.value,
          status: payrollByEmployee[entry.key]?['status'] as String? ?? 'draft',
          adjustments: [
            for (final row
                in payrollByEmployee[entry.key]?['payroll_adjustments'] ?? [])
              PayrollAdjustment.fromMap(row),
          ],
        ),
    ]..sort((a, b) => a.employeeName.compareTo(b.employeeName));
  }

  Future<void> addAdjustment({
    required String employeeId,
    required String type,
    required String concept,
    required double amount,
  }) async {
    final payroll = await _ensurePayroll(employeeId);
    final empresaId = await _empresaId();
    await _client.from('payroll_adjustments').insert({
      'empresa_id': empresaId,
      'payroll_id': payroll['id'],
      'type': type,
      'concept': concept.trim().isEmpty ? type : concept.trim(),
      'amount': amount,
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> deleteAdjustment(String id) async {
    await _client.from('payroll_adjustments').delete().eq('id', id);
  }

  Future<void> setPaid(String employeeId, bool paid) async {
    final payroll = await _ensurePayroll(employeeId);
    final userId = _client.auth.currentUser?.id;
    await _client.from('weekly_payrolls').update({
      'status': paid ? 'paid' : 'approved',
      'paid_at': paid ? DateTime.now().toIso8601String() : null,
      'paid_by': paid ? userId : null,
      'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    }).eq('id', payroll['id']);
  }

  Future<void> closeCurrentWeek() async {
    final period = await _currentPeriod();
    final userId = _client.auth.currentUser?.id;
    await _client.from('weekly_periods').update({
      'status': 'closed',
      'closed_by': userId,
      'closed_at': DateTime.now().toIso8601String(),
      'modificado_por': userId,
      'fecha_modificacion': DateTime.now().toIso8601String(),
    }).eq('id', period['id']);
  }

  Future<Map<String, dynamic>> _ensurePayroll(String employeeId) async {
    final empresaId = await _empresaId();
    final period = await _currentPeriod();
    final existing = await _client
        .from('weekly_payrolls')
        .select()
        .eq('empresa_id', empresaId)
        .eq('weekly_period_id', period['id'])
        .eq('employee_id', employeeId)
        .maybeSingle();
    if (existing != null) return existing;

    return await _client
        .from('weekly_payrolls')
        .insert({
          'empresa_id': empresaId,
          'weekly_period_id': period['id'],
          'employee_id': employeeId,
          'status': 'draft',
          'creado_por': _client.auth.currentUser?.id,
          'modificado_por': _client.auth.currentUser?.id,
          'fecha_modificacion': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
  }

  Future<Map<String, dynamic>> _currentPeriod() async {
    final empresaId = await _empresaId();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    final startText = _dateFormat.format(start);
    final endText = _dateFormat.format(end);

    final existing = await _client
        .from('weekly_periods')
        .select()
        .eq('empresa_id', empresaId)
        .eq('start_date', startText)
        .eq('end_date', endText)
        .maybeSingle();
    if (existing != null) return existing;

    return await _client
        .from('weekly_periods')
        .insert({
          'empresa_id': empresaId,
          'start_date': startText,
          'end_date': endText,
          'status': 'open',
          'creado_por': _client.auth.currentUser?.id,
          'modificado_por': _client.auth.currentUser?.id,
          'fecha_modificacion': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
  }

  double? _findRate({
    required List<dynamic> rates,
    required String employeeId,
    required String workTypeId,
    required DateTime workDate,
  }) {
    final candidates = rates.where((rate) {
      final matchesWorkType = rate['work_type_id'] == workTypeId;
      final matchesEmployee =
          rate['employee_id'] == null || rate['employee_id'] == employeeId;
      if (!matchesWorkType || !matchesEmployee) return false;

      final validFrom = DateTime.parse(rate['valid_from'] as String);
      final validUntil = rate['valid_until'] == null
          ? null
          : DateTime.parse(rate['valid_until'] as String);
      return !workDate.isBefore(validFrom) &&
          (validUntil == null || !workDate.isAfter(validUntil));
    }).toList();

    candidates.sort((a, b) {
      final aSpecific = a['employee_id'] == employeeId ? 1 : 0;
      final bSpecific = b['employee_id'] == employeeId ? 1 : 0;
      if (aSpecific != bSpecific) return bSpecific.compareTo(aSpecific);
      return (b['valid_from'] as String).compareTo(a['valid_from'] as String);
    });

    if (candidates.isEmpty) return null;
    return double.parse('${candidates.first['unit_price']}');
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
