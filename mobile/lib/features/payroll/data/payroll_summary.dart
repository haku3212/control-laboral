class PayrollLine {
  const PayrollLine({
    required this.entryId,
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.workTypeId,
    required this.workTypeName,
    required this.unit,
    required this.quantity,
    required this.workDate,
    this.rate,
  });

  final String entryId;
  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String workTypeId;
  final String workTypeName;
  final String unit;
  final double quantity;
  final DateTime workDate;
  final double? rate;

  double? get subtotal => rate == null ? null : quantity * rate!;
  bool get hasRate => rate != null;
}

class EmployeePayrollSummary {
  const EmployeePayrollSummary({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.lines,
    required this.adjustments,
    required this.status,
  });

  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final List<PayrollLine> lines;
  final List<PayrollAdjustment> adjustments;
  final String status;

  double get totalQuantity => lines.fold(0, (sum, line) => sum + line.quantity);

  List<PayrollLineTotal> get groupedLines {
    final grouped = <String, PayrollLineTotal>{};
    for (final line in lines) {
      final key = line.workTypeId;
      final current = grouped[key];
      grouped[key] = PayrollLineTotal(
        workTypeId: line.workTypeId,
        workTypeName: line.workTypeName,
        unit: line.unit,
        quantity: (current?.quantity ?? 0) + line.quantity,
        rate: current?.rate ?? line.rate,
        subtotal: (current?.subtotal ?? 0) + (line.subtotal ?? 0),
        hasMissingRate: (current?.hasMissingRate ?? false) || !line.hasRate,
      );
    }
    return grouped.values.toList()
      ..sort((a, b) => a.workTypeName.compareTo(b.workTypeName));
  }

  List<PayrollDayGroup> get dayGroups {
    final grouped = <DateTime, List<PayrollLine>>{};
    for (final line in lines) {
      final day = DateTime(
        line.workDate.year,
        line.workDate.month,
        line.workDate.day,
      );
      grouped.putIfAbsent(day, () => <PayrollLine>[]).add(line);
    }

    final groups = [
      for (final entry in grouped.entries)
        PayrollDayGroup(date: entry.key, lines: entry.value),
    ];
    groups.sort((a, b) => a.date.compareTo(b.date));
    return groups;
  }

  double get totalPayable {
    final value = grossPayable + adjustmentSignedTotal;
    return value < 0 ? 0 : value;
  }

  double get grossPayable => lines.fold(
        0,
        (sum, line) => sum + (line.subtotal ?? 0),
      );

  double get adjustmentSignedTotal => adjustments.fold(0, (sum, item) {
        return sum + (item.type == 'bonus' ? item.amount : -item.amount);
      });

  bool get hasMissingRates => lines.any((line) => !line.hasRate);
  bool get isPaid => status == 'paid';
}

class PayrollDayGroup {
  const PayrollDayGroup({
    required this.date,
    required this.lines,
  });

  final DateTime date;
  final List<PayrollLine> lines;

  double get total => lines.fold(0, (sum, line) => sum + (line.subtotal ?? 0));
  bool get hasMissingRates => lines.any((line) => !line.hasRate);
}

class PayrollLineTotal {
  const PayrollLineTotal({
    required this.workTypeId,
    required this.workTypeName,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.subtotal,
    required this.hasMissingRate,
  });

  final String workTypeId;
  final String workTypeName;
  final String unit;
  final double quantity;
  final double? rate;
  final double subtotal;
  final bool hasMissingRate;

  bool get hasRate => !hasMissingRate && rate != null;
}

class PayrollAdjustment {
  const PayrollAdjustment({
    required this.id,
    required this.type,
    required this.concept,
    required this.amount,
  });

  final String id;
  final String type;
  final String concept;
  final double amount;

  factory PayrollAdjustment.fromMap(Map<String, dynamic> map) {
    return PayrollAdjustment(
      id: map['id'] as String,
      type: map['type'] as String,
      concept: map['concept'] as String,
      amount: double.parse('${map['amount']}'),
    );
  }
}
