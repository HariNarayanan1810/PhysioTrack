class Exercise {
  const Exercise({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.name,
    required this.status,
    required this.notes,
  });

  final int id;
  final int patientId;
  final int doctorId;
  final String name;
  final String status;
  final String notes;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['exercise_id'] as int,
      patientId: json['patient_id'] as int,
      doctorId: json['doctor_id'] as int,
      name: (json['exercise_name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}
