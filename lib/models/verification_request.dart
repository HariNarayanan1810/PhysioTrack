class VerificationRequest {
  const VerificationRequest({
    required this.requestId,
    required this.doctorId,
    required this.fullName,
    required this.dateOfBirth,
    required this.qualification,
    required this.universityName,
    required this.yearOfGraduation,
    required this.yearsOfExperience,
    required this.specialization,
    required this.licenseNumber,
    required this.licenseIssuingAuthority,
    required this.licenseExpiryDate,
    required this.clinicName,
    required this.clinicAddress,
    required this.city,
    required this.area,
    required this.pincode,
    required this.clinicContactNumber,
    required this.consultationFee,
    required this.homeVisitAvailable,
    required this.latitude,
    required this.longitude,
    required this.licenseCertificateUrl,
    required this.degreeCertificateUrl,
    required this.status,
    required this.rejectionReason,
    required this.submittedAt,
    required this.removedReason,
    required this.removedAt,
    required this.doctorEmail,
    required this.doctorPhone,
    required this.doctorProfileImageUrl,
  });

  final int requestId;
  final int doctorId;
  final String fullName;
  final String dateOfBirth;
  final String qualification;
  final String universityName;
  final int yearOfGraduation;
  final int yearsOfExperience;
  final String specialization;
  final String licenseNumber;
  final String licenseIssuingAuthority;
  final String licenseExpiryDate;
  final String clinicName;
  final String clinicAddress;
  final String city;
  final String area;
  final String pincode;
  final String clinicContactNumber;
  final double consultationFee;
  final bool homeVisitAvailable;
  final double latitude;
  final double longitude;
  final String? licenseCertificateUrl;
  final String? degreeCertificateUrl;
  final String status;
  final String? rejectionReason;
  final String submittedAt;
  final String? removedReason;
  final String? removedAt;
  final String? doctorEmail;
  final String? doctorPhone;
  final String? doctorProfileImageUrl;

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory VerificationRequest.fromJson(Map<String, dynamic> json) {
    return VerificationRequest(
      requestId: _toInt(json['request_id']),
      doctorId: _toInt(json['doctor_id']),
      fullName: (json['full_name'] ?? '').toString(),
      dateOfBirth: (json['date_of_birth'] ?? '').toString(),
      qualification: (json['qualification'] ?? '').toString(),
      universityName: (json['university_name'] ?? '').toString(),
      yearOfGraduation: _toInt(json['year_of_graduation']),
      yearsOfExperience: _toInt(json['years_of_experience']),
      specialization: (json['specialization'] ?? '').toString(),
      licenseNumber: (json['license_number'] ?? '').toString(),
      licenseIssuingAuthority:
          (json['license_issuing_authority'] ?? '').toString(),
      licenseExpiryDate: (json['license_expiry_date'] ?? '').toString(),
      clinicName: (json['clinic_name'] ?? '').toString(),
      clinicAddress: (json['clinic_address'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      area: (json['area'] ?? '').toString(),
      pincode: (json['pincode'] ?? '').toString(),
      clinicContactNumber: (json['clinic_contact_number'] ?? '').toString(),
      consultationFee: _toDouble(json['consultation_fee']),
      homeVisitAvailable: _toInt(json['home_visit_available']) == 1,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      licenseCertificateUrl: json['license_certificate_url']?.toString(),
      degreeCertificateUrl: json['degree_certificate_url']?.toString(),
      status: (json['status'] ?? '').toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      submittedAt: (json['submitted_at'] ?? '').toString(),
      removedReason: json['removed_reason']?.toString(),
      removedAt: json['removed_at']?.toString(),
      doctorEmail: json['doctor_email']?.toString(),
      doctorPhone: json['doctor_phone']?.toString(),
      doctorProfileImageUrl: json['doctor_profile_image_url']?.toString(),
    );
  }
}
