class OperatorEntry {
  const OperatorEntry({
    required this.id,
    required this.workDate,
    required this.quantity,
    required this.status,
    required this.employeeName,
    required this.workTypeName,
    required this.workTypeUnit,
    this.note,
  });

  final String id;
  final DateTime workDate;
  final double quantity;
  final String status;
  final String employeeName;
  final String workTypeName;
  final String workTypeUnit;
  final String? note;

  factory OperatorEntry.fromMap(Map<String, dynamic> map) {
    return OperatorEntry(
      id: map['id'] as String,
      workDate: DateTime.parse(map['work_date'] as String),
      quantity: double.parse('${map['quantity']}'),
      status: map['status'] as String,
      note: map['note'] as String?,
      employeeName: map['employees']['full_name'] as String,
      workTypeName: map['work_types']['name'] as String,
      workTypeUnit: map['work_types']['unit'] as String,
    );
  }
}
