import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/employees/data/employees_repository.dart';
import '../../features/entries/data/work_entries_repository.dart';
import '../../features/operator/data/operator_entries_repository.dart';
import '../../features/payroll/data/payroll_repository.dart';
import '../../features/rates/data/rates_repository.dart';
import '../../features/work_types/data/work_types_repository.dart';

void refreshEmployeeData(WidgetRef ref) {
  ref.invalidate(employeesProvider);
  ref.invalidate(employeeAllowedWorkTypeIdsMapProvider);
  ref.invalidate(operatorEntriesProvider);
  ref.invalidate(dashboardStatsProvider);
}

void refreshWorkTypeData(WidgetRef ref) {
  ref.invalidate(workTypesProvider);
  ref.invalidate(employeeAllowedWorkTypeIdsMapProvider);
  ref.invalidate(payrollSummariesProvider);
  ref.invalidate(payrollSummariesByRangeProvider);
  ref.invalidate(dashboardStatsProvider);
}

void refreshRateData(WidgetRef ref) {
  ref.invalidate(ratesProvider);
  ref.invalidate(payrollSummariesProvider);
  ref.invalidate(payrollSummariesByRangeProvider);
}

void refreshEntryData(WidgetRef ref, {DateTime? date}) {
  ref.invalidate(workEntriesProvider);
  ref.invalidate(workEntriesByDateProvider);
  ref.invalidate(operatorEntriesProvider);
  ref.invalidate(operatorEntriesByDateProvider);
  ref.invalidate(payrollSummariesProvider);
  ref.invalidate(payrollSummariesByRangeProvider);
  ref.invalidate(dashboardStatsProvider);

  if (date != null) {
    ref.invalidate(workEntriesByDateProvider(date));
    ref.invalidate(operatorEntriesByDateProvider(date));
  }
}

void refreshPayrollData(WidgetRef ref) {
  ref.invalidate(payrollSummariesProvider);
  ref.invalidate(payrollSummariesByRangeProvider);
  ref.invalidate(dashboardStatsProvider);
}

void refreshForRoute(WidgetRef ref, String route) {
  switch (route) {
    case '/dashboard':
      ref.invalidate(dashboardStatsProvider);
    case '/entries':
      refreshEntryData(ref);
    case '/payroll':
    case '/reports':
      refreshPayrollData(ref);
    case '/employees':
      refreshEmployeeData(ref);
    case '/work-types':
      refreshWorkTypeData(ref);
    case '/rates':
      refreshRateData(ref);
    case '/operator':
      ref.invalidate(operatorEntriesProvider);
    case '/operator/new':
      refreshEmployeeData(ref);
      ref.invalidate(workTypesProvider);
    case '/operator/entries':
      refreshEntryData(ref);
  }
}
