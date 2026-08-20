class Review {
  const Review({
    required this.id,
    required this.doctorId,
    this.patientId,
    required this.patientName,
    required this.rating,
    required this.reviewText,
  });

  final int id;
  final int doctorId;
  final int? patientId;
  final String patientName;
  final double rating;
  final String reviewText;

  factory Review.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Review(
      id: json['review_id'] as int,
      doctorId: json['doctor_id'] as int,
      patientId: json['patient_id'] as int?,
      patientName: (json['patient_name'] ?? '').toString(),
      rating: parseDouble(json['rating']),
      reviewText: (json['review_text'] ?? '').toString(),
    );
  }
}
