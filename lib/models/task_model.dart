
class TaskModel {
  final int? id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final bool completed;
  final DateTime? dueDate;
  final DateTime? reminderDateTime;
  final DateTime createdAt;

  TaskModel({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    this.completed = false,
    this.dueDate,
    this.reminderDateTime,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert Task Object into Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'completed': completed ? 1 : 0,
      'dueDate': dueDate?.toIso8601String(),
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Convert SQLite Map into Task Object
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      priority: map['priority'] as String,
      completed: map['completed'] == 1,
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      reminderDateTime: map['reminderDateTime'] != null
          ? DateTime.parse(map['reminderDateTime'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
