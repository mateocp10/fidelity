class BusinessCategory {
  final int id;
  final String name;

  BusinessCategory({
    required this.id,
    required this.name,
  });

  factory BusinessCategory.fromJson(Map<String, dynamic> json) {
    return BusinessCategory(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
