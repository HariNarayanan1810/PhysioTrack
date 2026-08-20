class DoctorBlog {
  DoctorBlog({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.content,
    this.mediaUrl,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.doctorName = '',
  });

  final int id;
  final String title;
  final String shortDescription;
  final String content;
  final String? mediaUrl;
  final String status;
  final String createdAt;
  final String? updatedAt;
  final String doctorName;

  factory DoctorBlog.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return DoctorBlog(
      id: parseInt(json['id']),
      title: (json['title'] ?? '').toString(),
      shortDescription: (json['short_description'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      mediaUrl: json['media_url']?.toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: json['updated_at']?.toString(),
      doctorName: (json['doctor_name'] ?? '').toString(),
    );
  }
}
