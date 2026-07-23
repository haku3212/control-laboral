class Rate {
  const Rate({
    required this.id,
    required this.workTypeId,
    required this.workTypeName,
    required this.unitPrice,
    required this.validFrom,
    required this.active,
    this.employeeId,
    this.employeeName,
    this.validUntil,
  });

  final String id;
  final String workTypeId;
  final String workTypeName;
  final String? employeeId;
  final String? employeeName;
  final double unitPrice;
  final DateTime validFrom;
  final DateTime? validUntil;
  final bool active;

  factory Rate.fromMap(Map<String, dynamic> map) {
    return Rate(
      id: map['id'] as String,
      workTypeId: map['work_type_id'] as String,
      workTypeName: map['work_types']['name'] as String,
      employeeId: map['employee_id'] as String?,
      employeeName: map['employees']?['full_name'] as String?,
      unitPrice: double.parse('${map['unit_price']}'),
      validFrom: DateTime.parse(map['valid_from'] as String),
      validUntil: map['valid_until'] == null
          ? null
          : DateTime.parse(map['valid_until'] as String),
      active: map['active'] as bool? ?? true,
    );
  }
}
