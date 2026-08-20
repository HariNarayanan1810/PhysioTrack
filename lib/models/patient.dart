class Patient {
  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.email,
    required this.phone,
    required this.address,
    this.dob,
    this.profileImage,
    this.state,
    this.city,
    this.latitude,
    this.longitude,
    this.isRemoved = false,
    this.removedReason,
    this.removedAt,
  });

  final int id;
  final String name;
  final int age;
  final String email;
  final String phone;
  final String address;
  final String? dob;
  final String? profileImage;
  final String? state;
  final String? city;
  final double? latitude;
  final double? longitude;
  final bool isRemoved;
  final String? removedReason;
  final String? removedAt;

  factory Patient.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Patient(
      id: parseInt(json['patient_id']),
      name: (json['name'] ?? '').toString(),
      age: parseInt(json['age']),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      dob: json['dob']?.toString(),
      profileImage: json['profile_image']?.toString(),
      state: json['state']?.toString(),
      city: json['city']?.toString(),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      isRemoved: ((json['is_removed'] ?? 0) as num) == 1,
      removedReason: json['removed_reason']?.toString(),
      removedAt: json['removed_at']?.toString(),
    );
  }
}
