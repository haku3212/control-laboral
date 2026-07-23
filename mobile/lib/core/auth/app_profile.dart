class AppProfile {
  const AppProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.active,
    this.empresaId,
    this.employeeId,
  });

  final String id;
  final String fullName;
  final String role;
  final bool active;
  final String? empresaId;
  final String? employeeId;

  bool get isAdmin => role == 'admin' || role == 'gerente';
  bool get isOperator => role == 'operator' || role == 'encargado';
  String get roleLabel => isAdmin ? 'Gerente' : 'Encargado';

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      active: map['active'] as bool? ?? false,
      empresaId: map['empresa_id'] as String?,
      employeeId: map['employee_id'] as String?,
    );
  }
}
