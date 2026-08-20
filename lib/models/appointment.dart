class Appointment {
  Appointment({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.doctorName,
    required this.patientName,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    required this.visitType,
    this.preferredPaymentMethod = 'cash',
    this.distanceKm,
    this.sessionFee,
    this.isSpecialSession = false,
    this.specialFeeAmount,
    this.specialFeeReason,
    this.actualStartTime,
    this.actualEndTime,
    this.liveTrackingEnabled = false,
    this.doctorLiveLatitude,
    this.doctorLiveLongitude,
    this.currentEtaMinutes,
    this.lastLocationUpdatedAt,
  });

  final int id;
  final int doctorId;
  final int patientId;
  final String doctorName;
  final String patientName;
  final String appointmentDate;
  final String appointmentTime;
  final String status;
  final String visitType;
  final String preferredPaymentMethod;
  final double? distanceKm;
  final double? sessionFee;
  final bool isSpecialSession;
  final double? specialFeeAmount;
  final String? specialFeeReason;
  final String? actualStartTime;
  final String? actualEndTime;
  final bool liveTrackingEnabled;
  final double? doctorLiveLatitude;
  final double? doctorLiveLongitude;
  final int? currentEtaMinutes;
  final String? lastLocationUpdatedAt;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is num) return value.toInt();
      return null;
    }

    return Appointment(
      id: json['appointment_id'] as int,
      doctorId: json['doctor_id'] as int,
      patientId: json['patient_id'] as int,
      doctorName: json['doctor_name'] as String,
      patientName: json['patient_name'] as String,
      appointmentDate: json['appointment_date'] as String,
      appointmentTime: json['appointment_time'] as String,
      status: json['status'] as String,
      visitType: json['visit_type'] as String,
      preferredPaymentMethod: (json['preferred_payment_method'] ?? 'cash').toString(),
      distanceKm: parseDouble(json['distance_km']),
      sessionFee: parseDouble(json['session_fee']),
      isSpecialSession:
          json['is_special_session'] == true ||
          json['is_special_session'] == 1,
      specialFeeAmount: parseDouble(json['special_fee_amount']),
      specialFeeReason: json['special_fee_reason']?.toString(),
      actualStartTime: json['actual_start_time']?.toString(),
      actualEndTime: json['actual_end_time']?.toString(),
      liveTrackingEnabled:
          json['live_tracking_enabled'] == true ||
          json['live_tracking_enabled'] == 1,
      doctorLiveLatitude: parseDouble(json['doctor_live_latitude']),
      doctorLiveLongitude: parseDouble(json['doctor_live_longitude']),
      currentEtaMinutes: parseInt(json['current_eta_minutes']),
      lastLocationUpdatedAt: json['last_location_updated_at']?.toString(),
    );
  }
}

