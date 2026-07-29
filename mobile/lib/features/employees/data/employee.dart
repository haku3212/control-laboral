class Employee {
  const Employee({
    required this.id,
    required this.code,
    required this.fullName,
    required this.active,
    required this.restrictWorkTypes,
    this.documentNumber,
    this.phone,
    this.jobTitle,
    this.notes,
  });

  final String id;
  final String code;
  final String fullName;
  final bool active;
  final bool restrictWorkTypes;
  final String? documentNumber;
  final String? phone;
  final String? jobTitle;
  final String? notes;

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      code: map['code'] as String,
      fullName: map['full_name'] as String,
      active: map['active'] as bool? ?? true,
      restrictWorkTypes: map['restrict_work_types'] as bool? ?? false,
      documentNumber: map['document_number'] as String?,
      phone: map['phone'] as String?,
      jobTitle: map['job_title'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
