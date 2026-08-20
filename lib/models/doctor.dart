class Doctor {
  Doctor({
    required this.id,
    required this.name,
    required this.age,
    required this.qualification,
    required this.yearsOfExperience,
    required this.clinicName,
    required this.rating,
    required this.profileImageUrl,
    required this.latitude,
    required this.longitude,
    this.city = '',
    this.clinicAddress = '',
    this.consultationFee = 0,
    this.clinicFee = 0,
    this.homeVisitBaseFee = 0,
    this.perKmCharge,
    this.verificationStatus = 'not_applied',
    this.isRemoved = false,
    this.removedReason,
    this.removedAt,
  });

  final int id;
  final String name;
  final int age;
  final String qualification;
  final int yearsOfExperience;
  final String clinicName;
  final double rating;
  final String profileImageUrl;
  final double latitude;
  final double longitude;
  final String city;
  final String clinicAddress;
  final double consultationFee;
  final double clinicFee;
  final double homeVisitBaseFee;
  final double? perKmCharge;
  final String verificationStatus;
  final bool isRemoved;
  final String? removedReason;
  final String? removedAt;

  factory Doctor.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    final clinicFee = parseNum(json['clinic_fee'] ?? json['consultation_fee']);
    final homeVisitBaseFee = parseNum(
      json['home_visit_base_fee'] ?? json['clinic_fee'] ?? json['consultation_fee'],
    );

    return Doctor(
      id: json['doctor_id'] as int,
      name: json['name'] as String,
      age: json['age'] as int,
      qualification: json['qualification'] as String,
      yearsOfExperience: json['years_of_experience'] as int,
      clinicName: json['clinic_name'] as String,
      rating: parseNum(json['rating']),
      profileImageUrl: json['profile_image_url'] as String,
      latitude: parseNum(json['latitude']),
      longitude: parseNum(json['longitude']),
      city: (json['city'] ?? '').toString(),
      clinicAddress: (json['clinic_address'] ?? '').toString(),
      consultationFee: clinicFee,
      clinicFee: clinicFee,
      homeVisitBaseFee: homeVisitBaseFee,
      perKmCharge: json['per_km_charge'] == null
          ? null
          : parseNum(json['per_km_charge']),
      verificationStatus: (json['verification_status'] ?? 'not_applied')
          .toString()
          .toLowerCase(),
      isRemoved: ((json['is_removed'] ?? 0) as num) == 1,
      removedReason: json['removed_reason']?.toString(),
      removedAt: json['removed_at']?.toString(),
    );
  }
}
