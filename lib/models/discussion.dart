class DiscussionAnswer {
  DiscussionAnswer({
    required this.id,
    required this.questionId,
    required this.doctorId,
    required this.doctorName,
    required this.answerText,
    required this.createdAt,
  });

  final int id;
  final int questionId;
  final int doctorId;
  final String doctorName;
  final String answerText;
  final String createdAt;

  factory DiscussionAnswer.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return DiscussionAnswer(
      id: parseInt(json['id']),
      questionId: parseInt(json['question_id']),
      doctorId: parseInt(json['doctor_id']),
      doctorName: (json['doctor_name'] ?? '').toString(),
      answerText: (json['answer_text'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class DiscussionQuestion {
  DiscussionQuestion({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.questionText,
    required this.createdAt,
    required this.answers,
  });

  final int id;
  final int patientId;
  final String patientName;
  final String questionText;
  final String createdAt;
  final List<DiscussionAnswer> answers;

  factory DiscussionQuestion.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final answerRows = (json['answers'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => DiscussionAnswer.fromJson(e as Map<String, dynamic>))
        .toList();

    return DiscussionQuestion(
      id: parseInt(json['id']),
      patientId: parseInt(json['patient_id']),
      patientName: (json['patient_name'] ?? '').toString(),
      questionText: (json['question_text'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      answers: answerRows,
    );
  }
}
