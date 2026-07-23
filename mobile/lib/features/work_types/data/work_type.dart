class WorkType {
  const WorkType({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.category,
    required this.active,
  });

  final String id;
  final String code;
  final String name;
  final String unit;
  final String category;
  final bool active;

  factory WorkType.fromMap(Map<String, dynamic> map) {
    return WorkType(
      id: map['id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      unit: map['unit'] as String,
      category: map['category'] as String,
      active: map['active'] as bool? ?? true,
    );
  }
}
