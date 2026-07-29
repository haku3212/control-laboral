class WorkEntry {
  const WorkEntry({
    required this.id,
    required this.employeeCode,
    required this.employeeName,
    required this.workTypeName,
    required this.workDate,
    required this.quantity,
    required this.unit,
    required this.status,
    this.note,
  });

  final String id;
  final String employeeCode;
  final String employeeName;
  final String workTypeName;
  final DateTime workDate;
  final double quantity;
  final String unit;
  final String status;
  final String? note;

  factory WorkEntry.fromMap(Map<String, dynamic> map) {
    return WorkEntry(
      id: map['id'] as String,
      employeeCode: map['employees']['code'] as String,
      employeeName: map['employees']['full_name'] as String,
      workTypeName: map['work_types']['name'] as String,
      unit: map['work_types']['unit'] as String,
      workDate: DateTime.parse(map['work_date'] as String),
      quantity: double.parse('${map['quantity']}'),
      status: map['status'] as String,
      note: map['note'] as String?,
    );
  }
}
