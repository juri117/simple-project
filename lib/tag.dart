class Tag {
  final int id;
  final String shortName;
  final String description;
  final String color;
  final String createdAt;
  final String updatedAt;

  Tag({
    required this.id,
    required this.shortName,
    required this.description,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] ?? 0,
      shortName: json['short_name'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#3B82F6',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'short_name': shortName,
      'description': description,
      'color': color,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  String toString() {
    return 'Tag(id: $id, shortName: $shortName, description: $description, color: $color)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tag && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
