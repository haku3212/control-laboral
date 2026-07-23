class PayrollLine {
  const PayrollLine({
    required this.entryId,
    required this.employeeId,
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
    required this.employeeName,
    required this.lines,
    required this.adjustments,
    required this.status,
  });

  final String employeeId;
  final String employeeName;
  final List<PayrollLine> lines;
  final List<PayrollAdjustment> adjustments;
  final String status;

  double get totalQuantity =>
      lines.fold(0, (sum, line) => sum + line.quantity);

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
