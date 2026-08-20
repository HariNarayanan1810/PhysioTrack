class UserReport {
  const UserReport({
    required this.id,
    required this.reporterRole,
    required this.targetRole,
    required this.reasonCategory,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reporterDoctorId,
    this.reporterPatientId,
    this.targetDoctorId,
    this.targetPatientId,
    this.reporterName,
    this.targetName,
    this.adminNote,
    this.resolvedAt,
  });

  final int id;
  final String reporterRole;
  final String targetRole;
  final int? reporterDoctorId;
  final int? reporterPatientId;
  final int? targetDoctorId;
  final int? targetPatientId;
  final String reasonCategory;
  final String description;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? reporterName;
  final String? targetName;
  final String? adminNote;
  final String? resolvedAt;

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  factory UserReport.fromJson(Map<String, dynamic> json) {
    return UserReport(
      id: _toInt(json['id']) ?? 0,
      reporterRole: (json['reporter_role'] ?? '').toString(),
      targetRole: (json['target_role'] ?? '').toString(),
      reporterDoctorId: _toInt(json['reporter_doctor_id']),
      reporterPatientId: _toInt(json['reporter_patient_id']),
      targetDoctorId: _toInt(json['target_doctor_id']),
      targetPatientId: _toInt(json['target_patient_id']),
      reasonCategory: (json['reason_category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      reporterName: json['reporter_name']?.toString(),
      targetName: json['target_name']?.toString(),
      adminNote: json['admin_note']?.toString(),
      resolvedAt: json['resolved_at']?.toString(),
    );
  }
}
