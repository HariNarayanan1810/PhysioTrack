class SessionUser {
  const SessionUser({
    required this.userId,
    required this.role,
    required this.name,
    required this.email,
    this.doctorId,
    this.patientId,
  });

  final int userId;
  final String role;
  final String name;
  final String email;
  final int? doctorId;
  final int? patientId;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return SessionUser(
      userId: parseInt(json['user_id']) ?? 0,
      role: (json['role'] ?? '').toString().toUpperCase(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      doctorId: parseInt(json['doctor_id']),
      patientId: parseInt(json['patient_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role': role,
      'name': name,
      'email': email,
      'doctor_id': doctorId,
      'patient_id': patientId,
    };
  }
}
