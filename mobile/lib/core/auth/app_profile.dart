class AppProfile {
  const AppProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.active,
    this.employeeId,
  });

  final String id;
  final String fullName;
  final String role;
  final bool active;
  final String? employeeId;

  bool get isAdmin => role == 'admin';
  bool get isOperator => role == 'operator';

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      active: map['active'] as bool? ?? false,
      employeeId: map['employee_id'] as String?,
    );
  }
}
