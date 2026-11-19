
class HabitModel {
  final int? id;
  final String name;
  final String description;
  final String category;
  final DateTime createdAt;
  final bool isActive;

  // Daily habit reminder time in HH:mm format.
  final String? reminderTime;

  HabitModel({
    this.id,
    required this.name,
    required this.description,
    required this.category,
    DateTime? createdAt,
    this.isActive = true,
    this.reminderTime,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'reminderTime': reminderTime,
    };
  }

  factory HabitModel.fromMap(Map<String, dynamic> map) {
    return HabitModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isActive: map['isActive'] == 1,
      reminderTime: map['reminderTime'] as String?,
    );
  }

  HabitModel copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    DateTime? createdAt,
    bool? isActive,
    String? reminderTime,
    bool clearReminderTime = false,
  }) {
    return HabitModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      reminderTime: clearReminderTime
          ? null
          : reminderTime ?? this.reminderTime,
    );
  }
}
