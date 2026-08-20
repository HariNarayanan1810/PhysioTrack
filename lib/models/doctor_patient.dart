class DoctorPatientSummary {
  DoctorPatientSummary({
    required this.patientId,
    required this.name,
    required this.age,
    required this.appointmentType,
    required this.lastAppointmentDate,
    required this.profileImage,
  });

  final int patientId;
  final String name;
  final int age;
  final String appointmentType;
  final String lastAppointmentDate;
  final String profileImage;

  factory DoctorPatientSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return DoctorPatientSummary(
      patientId: parseInt(json['patient_id']),
      name: (json['name'] ?? '').toString(),
      age: parseInt(json['age']),
      appointmentType: (json['appointment_type'] ?? '').toString(),
      lastAppointmentDate: (json['last_appointment_date'] ?? '').toString(),
      profileImage: (json['profile_image'] ?? '').toString(),
    );
  }
}

class DoctorPatientMedia {
  DoctorPatientMedia({
    required this.id,
    required this.filePath,
    required this.fileType,
    required this.createdAt,
  });

  final int id;
  final String filePath;
  final String fileType;
  final String createdAt;

  factory DoctorPatientMedia.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return DoctorPatientMedia(
      id: parseInt(json['id']),
      filePath: (json['file_path'] ?? '').toString(),
      fileType: (json['file_type'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class DoctorPatientItem {
  DoctorPatientItem({
    required this.id,
    required this.value,
    required this.createdAt,
  });

  final int id;
  final String value;
  final String createdAt;
}

class DoctorPatientDetail {
  DoctorPatientDetail({
    required this.patientId,
    required this.name,
    required this.email,
    required this.age,
    required this.state,
    required this.city,
    required this.address,
    required this.profileImage,
    this.noteId,
    this.problemDescription = '',
    this.adviceNotes = '',
    this.suggestedNextAppointment,
    this.treatmentId,
    this.media = const [],
    this.exercises = const [],
    this.advice = const [],
  });

  final int patientId;
  final String name;
  final String email;
  final int age;
  final String state;
  final String city;
  final String address;
  final String profileImage;
  final int? noteId;
  final int? treatmentId;
  final String problemDescription;
  final String adviceNotes;
  final String? suggestedNextAppointment;
  final List<DoctorPatientMedia> media;
  final List<DoctorPatientItem> exercises;
  final List<DoctorPatientItem> advice;

  factory DoctorPatientDetail.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final patient = (json['patient'] as Map<String, dynamic>? ?? {});
    final note = (json['note'] as Map<String, dynamic>?);
    final treatment = (json['treatment'] as Map<String, dynamic>?);
    final mediaRaw = (json['media'] as List<dynamic>? ?? []);
    final exerciseRaw = (json['exercises'] as List<dynamic>? ?? []);
    final adviceRaw = (json['advice'] as List<dynamic>? ?? []);

    return DoctorPatientDetail(
      patientId: parseInt(patient['patient_id']),
      name: (patient['name'] ?? '').toString(),
      email: (patient['email'] ?? '').toString(),
      age: parseInt(patient['age']),
      state: (patient['state'] ?? '').toString(),
      city: (patient['city'] ?? '').toString(),
      address: (patient['address'] ?? '').toString(),
      profileImage: (patient['profile_image'] ?? '').toString(),
      noteId: note == null ? null : parseInt(note['id']),
      treatmentId: treatment == null ? null : parseInt(treatment['id']),
      problemDescription: (note?['problem_description'] ??
              treatment?['problem_description'] ??
              '')
          .toString(),
      adviceNotes: (treatment?['advice_notes'] ?? '').toString(),
      suggestedNextAppointment:
          treatment?['suggested_next_appointment']?.toString(),
      media: mediaRaw
          .map((e) => DoctorPatientMedia.fromJson(e as Map<String, dynamic>))
          .toList(),
      exercises: exerciseRaw.map((e) {
        final row = e as Map<String, dynamic>;
        return DoctorPatientItem(
          id: parseInt(row['id']),
          value: (row['exercise_name'] ?? '').toString(),
          createdAt: (row['created_at'] ?? '').toString(),
        );
      }).toList(),
      advice: adviceRaw.map((e) {
        final row = e as Map<String, dynamic>;
        return DoctorPatientItem(
          id: parseInt(row['id']),
          value: (row['advice_text'] ?? '').toString(),
          createdAt: (row['created_at'] ?? '').toString(),
        );
      }).toList(),
    );
  }
}
