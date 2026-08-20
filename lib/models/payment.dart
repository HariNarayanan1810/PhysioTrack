class Payment {
  Payment({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.patientName,
    required this.doctorName,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.visitType,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentDate,
    required this.createdAt,
  });

  final int id;
  final int appointmentId;
  final int patientId;
  final int doctorId;
  final String patientName;
  final String doctorName;
  final String appointmentDate;
  final String appointmentTime;
  final String visitType;
  final double amount;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentDate;
  final String createdAt;

  factory Payment.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0;
      return 0;
    }

    return Payment(
      id: parseInt(json['id']),
      appointmentId: parseInt(json['appointment_id']),
      patientId: parseInt(json['patient_id']),
      doctorId: parseInt(json['doctor_id']),
      patientName: (json['patient_name'] ?? '').toString(),
      doctorName: (json['doctor_name'] ?? '').toString(),
      appointmentDate: (json['appointment_date'] ?? '').toString(),
      appointmentTime: (json['appointment_time'] ?? '').toString(),
      visitType: (json['visit_type'] ?? '').toString(),
      amount: parseDouble(json['amount']),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      paymentStatus: (json['payment_status'] ?? '').toString(),
      paymentDate: json['payment_date']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
