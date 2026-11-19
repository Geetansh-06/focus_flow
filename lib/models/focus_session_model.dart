
class FocusSessionModel {
  final int? id;
  final int durationSeconds;
  final DateTime completedAt;

  FocusSessionModel({
    this.id,
    required this.durationSeconds,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'durationSeconds': durationSeconds,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory FocusSessionModel.fromMap(Map<String, dynamic> map) {
    return FocusSessionModel(
      id: map['id'] as int?,
      durationSeconds: map['durationSeconds'] as int,
      completedAt: DateTime.parse(map['completedAt'] as String),
    );
  }
}
