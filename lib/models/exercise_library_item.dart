class ExerciseLibraryItem {
  const ExerciseLibraryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.demoMediaUrl,
    required this.exerciseType,
    required this.recommendedReps,
    required this.repCount,
    required this.defaultDurationSeconds,
  });

  final int id;
  final String name;
  final String description;
  final String demoMediaUrl;
  final String exerciseType;
  final String recommendedReps;
  final int? repCount;
  final int? defaultDurationSeconds;

  factory ExerciseLibraryItem.fromJson(Map<String, dynamic> json) {
    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is num) return value.toInt();
      return null;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    return ExerciseLibraryItem(
      id: parseInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      demoMediaUrl: (json['demo_media_url'] ?? '').toString(),
      exerciseType: (json['exercise_type'] ?? 'time').toString(),
      recommendedReps: (json['recommended_reps'] ?? '').toString(),
      repCount: parseNullableInt(json['rep_count']),
      defaultDurationSeconds: parseNullableInt(json['default_duration_seconds']),
    );
  }
}
