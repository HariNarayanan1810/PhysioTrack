import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/appointment.dart';
import '../models/doctor.dart';
import '../models/doctor_blog.dart';
import '../models/doctor_patient.dart';
import '../models/discussion.dart';
import '../models/exercise.dart';
import '../models/exercise_library_item.dart';
import '../models/payment.dart';
import '../models/patient.dart';
import '../models/review.dart';
import '../models/session_user.dart';
import '../models/user_report.dart';
import '../models/verification_request.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _webBaseUrl = 'http://localhost:4000';
  //for emulator
  // static const String _androidBaseUrl = 'http://10.0.2.2:4000';
  //for physical device
  //static const String _androidBaseUrl = 'http://--wireless lan adapter wifi ipv4 address';

  static const String _androidBaseUrl = 'http://192.168.1.6:4000';

  String get _baseUrl => kIsWeb ? _webBaseUrl : _androidBaseUrl;
  String resolveFileUrl(String? url) {
    final value = (url ?? '').trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$_baseUrl$value';
  }

  Future<Map<String, String>> _authorizedHeaders({
    Map<String, String>? base,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    final token = await user.getIdToken();
    return {...?base, 'Authorization': 'Bearer $token'};
  }

  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/devices/register-token'),
      headers: headers,
      body: jsonEncode({'fcm_token': fcmToken, 'platform': platform}),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to register device token');
    }
  }

  Future<List<Doctor>> getApprovedDoctors() async {
    final res = await _client.get(Uri.parse('$_baseUrl/doctors/approved'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load approved doctors');
    }
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Doctor.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getDoctorDashboardSummary() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctor/dashboard-summary'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load doctor dashboard summary');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDoctorTodaySchedule() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctor/today-schedule'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load today schedule');
    }
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<DoctorBlog>> getRecentDoctorBlogs() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctor/blogs/recent'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load recent blogs');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => DoctorBlog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DoctorBlog>> getDoctorBlogFeed({int limit = 3}) async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctor/blogs/feed?limit=$limit'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load blog feed');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => DoctorBlog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DoctorBlog>> getMyDoctorBlogs() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctor/blogs/mine'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load my blogs');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => DoctorBlog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DoctorBlog> getDoctorBlogById(int id) async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctor/blogs/$id'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load blog');
    }
    return DoctorBlog.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<String> uploadDoctorBlogImageBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final headers = await _authorizedHeaders();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/doctor/blogs/upload-image'),
    );
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: fileName),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw Exception('Failed to upload blog image');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['media_url'] ?? '').toString();
  }

  Future<void> createDoctorBlog({
    required String title,
    required String shortDescription,
    required String content,
    String? mediaUrl,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/doctor/blogs'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'short_description': shortDescription,
        'content': content,
        'media_url': mediaUrl ?? '',
        'status': 'published',
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to publish blog');
    }
  }

  Future<void> updateDoctorBlog({
    required int blogId,
    required String title,
    required String shortDescription,
    required String content,
    String? mediaUrl,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/doctor/blogs/$blogId'),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'short_description': shortDescription,
        'content': content,
        'media_url': mediaUrl ?? '',
        'status': 'published',
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update blog');
    }
  }

  Future<List<DiscussionQuestion>> getDiscussions() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/discussions'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load discussions');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => DiscussionQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDiscussionQuestion(String questionText) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/discussions'),
      headers: headers,
      body: jsonEncode({'question_text': questionText}),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to post question');
    }
  }

  Future<void> createDiscussionAnswer({
    required int questionId,
    required String answerText,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/discussions/$questionId/answers'),
      headers: headers,
      body: jsonEncode({'answer_text': answerText}),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to submit answer');
    }
  }

  Future<List<Doctor>> getDoctors({
    bool verifiedOnly = false,
    bool removedOnly = false,
    int? userId,
  }) async {
    final params = <String, String>{};
    if (removedOnly) {
      params['removed'] = 'true';
    } else if (verifiedOnly) {
      params['verified'] = 'true';
    }
    if (userId != null) params['user_id'] = '$userId';

    final uri = Uri.parse('$_baseUrl/doctors').replace(queryParameters: params);
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load doctors');
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Doctor.fromJson(e)).toList();
  }

  Future<Doctor?> getDoctorByUserId(int userId) async {
    final doctors = await getDoctors(userId: userId);
    if (doctors.isEmpty) return null;
    return doctors.first;
  }

  Future<List<DoctorPatientSummary>> getDoctorPatients({
    required int doctorId,
    required String appointmentType,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/patients/$doctorId',
    ).replace(queryParameters: {'appointment_type': appointmentType});
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load doctor patients');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => DoctorPatientSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DoctorPatientDetail> getDoctorPatientDetail({
    required int doctorId,
    required int patientId,
  }) async {
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctor/patient/$doctorId/$patientId'),
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // Fall through
      }
      throw Exception('Failed to load patient detail');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return DoctorPatientDetail.fromJson(data);
  }

  Future<List<String>> getDoctorPatientExerciseCompletedDays({
    required int doctorId,
    required int patientId,
    required int month,
    required int year,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/patient/$doctorId/$patientId/completed-days',
    ).replace(queryParameters: {'month': '$month', 'year': '$year'});
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load patient completed days');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<void> createDoctorPatientProblem({
    required int doctorId,
    required int patientId,
    required String problemDescription,
    String? suggestedNextAppointment,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/doctor/patient/problem'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'problem_description': problemDescription,
        'suggested_next_appointment': suggestedNextAppointment ?? '',
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to save problem description');
    }
  }

  Future<void> updateDoctorPatientProblem({
    required int doctorId,
    required int patientId,
    required String problemDescription,
    String? suggestedNextAppointment,
  }) async {
    final res = await _client.put(
      Uri.parse('$_baseUrl/doctor/patient/problem'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'problem_description': problemDescription,
        'suggested_next_appointment': suggestedNextAppointment ?? '',
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update problem description');
    }
  }

  Future<void> addDoctorPatientExercise({
    required int doctorId,
    required int patientId,
    required String exerciseName,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/doctor/patient/exercise'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'exercise_name': exerciseName,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to add exercise');
  }

  Future<void> deleteDoctorPatientExercise({
    required int doctorId,
    required int exerciseId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/patient/exercise/$exerciseId',
    ).replace(queryParameters: {'doctor_id': '$doctorId'});
    final res = await _client.delete(uri);
    if (res.statusCode != 200) throw Exception('Failed to delete exercise');
  }

  Future<void> addDoctorPatientAdvice({
    required int doctorId,
    required int patientId,
    required String adviceText,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/doctor/patient/advice'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'advice_text': adviceText,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to add advice');
  }

  Future<void> deleteDoctorPatientAdvice({
    required int doctorId,
    required int adviceId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/patient/advice/$adviceId',
    ).replace(queryParameters: {'doctor_id': '$doctorId'});
    final res = await _client.delete(uri);
    if (res.statusCode != 200) throw Exception('Failed to delete advice');
  }

  Future<void> uploadDoctorPatientMediaBytes({
    required int doctorId,
    required int patientId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/doctor/patient/media'),
    );
    request.fields['doctor_id'] = '$doctorId';
    request.fields['patient_id'] = '$patientId';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    final streamed = await request.send();
    if (streamed.statusCode != 201) {
      throw Exception('Failed to upload media');
    }
  }

  Future<void> deleteDoctorPatientMedia({
    required int doctorId,
    required int mediaId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/doctor/patient/media/$mediaId',
    ).replace(queryParameters: {'doctor_id': '$doctorId'});
    final res = await _client.delete(uri);
    if (res.statusCode != 200) throw Exception('Failed to delete media');
  }

  Future<Map<String, dynamic>> getPatientTreatment(int patientId) async {
    final res = await _client.get(
      Uri.parse('$_baseUrl/patients/treatment/$patientId'),
    );
    if (res.statusCode != 200) throw Exception('Failed to load treatment plan');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPatientTreatmentExercises(
    int patientId,
  ) async {
    final res = await _client.get(
      Uri.parse('$_baseUrl/patients/exercises/$patientId'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load treatment exercises');
    }
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<void> markPatientExerciseDone({
    required int exerciseId,
    required int patientId,
    required bool completed,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/patients/exercises/mark-done'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': exerciseId,
        'patient_id': patientId,
        'completed_flag': completed ? 1 : 0,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update exercise progress');
    }
  }

  Future<void> confirmSuggestedAppointment({
    required int treatmentId,
    required int patientId,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/appointments/confirm'),
      headers: headers,
      body: jsonEncode({'treatment_id': treatmentId, 'patient_id': patientId}),
    );
    if (res.statusCode != 201) throw Exception('Failed to confirm appointment');
  }

  Future<void> rescheduleSuggestedAppointment({
    required int treatmentId,
    required int patientId,
    required String suggestedNextAppointment,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/appointments/reschedule'),
      headers: headers,
      body: jsonEncode({
        'treatment_id': treatmentId,
        'patient_id': patientId,
        'suggested_next_appointment': suggestedNextAppointment,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to reschedule appointment');
    }
  }

  Future<Map<String, dynamic>> getTodayPatientExercises() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/patients/exercises/today'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load today exercises');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> startPatientExerciseDay() async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/patients/exercises/start-day'),
      headers: headers,
      body: jsonEncode({}),
    );
    if (res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final message = (body['message'] ?? '').toString();
        throw Exception(message.isEmpty ? 'Failed to start day' : message);
      } catch (_) {
        throw Exception('Failed to start day');
      }
    }
  }

  Future<void> completeOnePatientExercise({
    required int exerciseId,
    String? date,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/patients/exercises/complete-one'),
      headers: headers,
      body: jsonEncode({'exercise_id': exerciseId, 'date': date ?? ''}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to mark exercise complete');
    }
  }

  Future<void> completePatientExerciseDay({String? date}) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/patients/exercises/complete-day'),
      headers: headers,
      body: jsonEncode({'date': date ?? ''}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to complete day');
    }
  }

  Future<List<String>> getPatientExerciseCompletedDays({
    required int month,
    required int year,
  }) async {
    final headers = await _authorizedHeaders();
    final uri = Uri.parse(
      '$_baseUrl/patient/exercise/completed-days',
    ).replace(queryParameters: {'month': '$month', 'year': '$year'});
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load completed days');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<List<String>> getPatientExerciseCalendar() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/patients/exercises/calendar'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load exercise calendar');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((e) => e.toString()).toList();
  }

  Future<List<Payment>> getDoctorPayments() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctor/payments'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load doctor payments');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => Payment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Payment>> getPatientPayments() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/patient/payments'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load payment history');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => Payment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> createPaymentOrder({
    required int paymentId,
    required double amount,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/payments/create-order'),
      headers: headers,
      body: jsonEncode({'payment_id': paymentId, 'amount': amount}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to create payment order');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> confirmPayment({
    required int paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/payments/confirm'),
      headers: headers,
      body: jsonEncode({
        'payment_id': paymentId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      }),
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // fall through to generic error
      }
      throw Exception('Failed to confirm payment');
    }
  }

  Future<void> failPayment({required int paymentId}) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/payments/fail'),
      headers: headers,
      body: jsonEncode({'payment_id': paymentId}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update failed status');
    }
  }

  Future<Map<String, dynamic>> getAdminPayments() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/admin/payments'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load payments');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final summary =
        (body['summary'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final paymentRows = (body['payments'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Payment.fromJson(e as Map<String, dynamic>))
        .toList();
    return {'summary': summary, 'payments': paymentRows};
  }

  Future<void> markPaymentPaid(
    int paymentId, {
    String paymentMethod = 'cash',
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/payments/$paymentId/mark-paid'),
      headers: headers,
      body: jsonEncode({'payment_method': paymentMethod}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to mark payment as paid');
    }
  }

  Future<void> markPaymentPartial(
    int paymentId, {
    required double amount,
    String paymentMethod = 'cash',
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/payments/$paymentId/mark-partial'),
      headers: headers,
      body: jsonEncode({'amount': amount, 'payment_method': paymentMethod}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to mark payment as partial');
    }
  }

  Future<List<Patient>> getPatients({
    int? doctorId,
    int? userId,
    bool removedOnly = false,
  }) async {
    final params = <String, String>{};
    if (doctorId != null) params['doctor_id'] = '$doctorId';
    if (userId != null) params['user_id'] = '$userId';
    if (removedOnly) params['removed'] = 'true';

    final uri = Uri.parse(
      '$_baseUrl/patients',
    ).replace(queryParameters: params);
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load patients');
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Patient.fromJson(e)).toList();
  }

  Future<Patient> getPatientById(int patientId) async {
    final res = await _client.get(Uri.parse('$_baseUrl/patients/$patientId'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load patient profile');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return Patient.fromJson(data);
  }

  Future<void> removePatient(
    int patientId, {
    required String removedReason,
  }) async {
    final res = await _client.put(
      Uri.parse('$_baseUrl/patients/$patientId/remove'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'removed_reason': removedReason}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to remove patient');
    }
  }

  Future<Patient?> getPatientProfile() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/patients/profile'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('Failed to load profile');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final exists = data['exists'] == true;
    if (!exists) return null;
    final profile = data['profile'] as Map<String, dynamic>;
    return Patient.fromJson(profile);
  }

  Future<String> uploadPatientProfileImageBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final headers = await _authorizedHeaders();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/patients/profile-image'),
    );
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes('profile_image', bytes, filename: fileName),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw Exception('Failed to upload image');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['image_url'] ?? '').toString();
  }

  Future<void> createPatientProfile({
    required String name,
    required String email,
    required String phone,
    required String dob,
    required String state,
    required String city,
    required String address,
    required double latitude,
    required double longitude,
    String? profileImage,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/patients/profile'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'dob': dob,
        'state': state,
        'city': city,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'profile_image': profileImage ?? '',
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to create profile');
    }
  }

  Future<void> updatePatientProfile({
    required String name,
    required String phone,
    required String dob,
    required String state,
    required String city,
    required String address,
    required double latitude,
    required double longitude,
    String? profileImage,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/patients/profile'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'dob': dob,
        'state': state,
        'city': city,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'profile_image': profileImage ?? '',
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update profile');
    }
  }

  Future<List<Appointment>> getAppointments({
    int? doctorId,
    int? patientId,
  }) async {
    final params = <String, String>{};
    if (doctorId != null) params['doctor_id'] = '$doctorId';
    if (patientId != null) params['patient_id'] = '$patientId';

    final uri = Uri.parse(
      '$_baseUrl/appointments',
    ).replace(queryParameters: params);
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load appointments');
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Appointment.fromJson(e)).toList();
  }

  Future<List<Exercise>> getExercises({int? patientId, int? doctorId}) async {
    final params = <String, String>{};
    if (patientId != null) params['patient_id'] = '$patientId';
    if (doctorId != null) params['doctor_id'] = '$doctorId';

    final uri = Uri.parse(
      '$_baseUrl/exercises',
    ).replace(queryParameters: params);
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load exercises');
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Exercise.fromJson(e)).toList();
  }

  Future<SessionUser> getUserById(int userId) async {
    final res = await _client.get(Uri.parse('$_baseUrl/users/$userId'));
    if (res.statusCode != 200) throw Exception('Failed to load user');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return SessionUser.fromJson(data);
  }

  Future<Doctor> getDoctorById(int doctorId) async {
    final res = await _client.get(Uri.parse('$_baseUrl/doctors/$doctorId'));
    if (res.statusCode != 200) throw Exception('Failed to load doctor details');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return Doctor.fromJson(data);
  }

  Future<List<Review>> getReviews(int doctorId) async {
    final uri = Uri.parse(
      '$_baseUrl/reviews',
    ).replace(queryParameters: {'doctor_id': '$doctorId'});
    final res = await _client.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load reviews');
    final data = jsonDecode(res.body) as List;
    return data.map((e) => Review.fromJson(e)).toList();
  }

  Future<void> createReview({
    required int doctorId,
    required int? patientId,
    required String patientName,
    required double rating,
    required String reviewText,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/reviews'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'patient_name': patientName,
        'rating': rating,
        'review_text': reviewText,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to submit review');
  }

  Future<void> updateAppointmentStatus({
    required int appointmentId,
    required String status,
    bool isSpecialSession = false,
    double? specialFeeAmount,
    String? specialFeeReason,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/appointments/$appointmentId/status'),
      headers: headers,
      body: jsonEncode({
        'status': status,
        'is_special_session': isSpecialSession,
        'special_fee_amount': specialFeeAmount,
        'special_fee_reason': specialFeeReason,
      }),
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // Fall through to generic error below.
      }
      throw Exception('Failed to update appointment status');
    }
  }

  Future<void> updateHomeVisitLiveTracking({
    required int appointmentId,
    required double latitude,
    required double longitude,
    int? etaMinutes,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/appointments/$appointmentId/live-tracking'),
      headers: headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'eta_minutes': etaMinutes,
      }),
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // Fall through.
      }
      throw Exception('Failed to update live tracking');
    }
  }

  Future<Map<String, dynamic>?> getPatientHomeVisitTracking(
    int patientId,
  ) async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/appointments/home-visit/live/$patientId'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load live tracking');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tracking = data['tracking'];
    if (tracking is Map<String, dynamic>) {
      return tracking;
    }
    return null;
  }

  Future<Map<String, dynamic>> getDirections({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    String mode = 'driving',
  }) async {
    final headers = await _authorizedHeaders();
    final uri = Uri.parse('$_baseUrl/maps/directions').replace(
      queryParameters: {
        'origin': '$originLatitude,$originLongitude',
        'destination': '$destinationLatitude,$destinationLongitude',
        'mode': mode,
      },
    );
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // Fall through.
      }
      throw Exception('Failed to load directions');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> stopDoctorHomeVisitDay() async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/appointments/home-visit/stop-day'),
      headers: headers,
      body: jsonEncode({}),
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // Fall through.
      }
      throw Exception('Failed to stop today home visit session');
    }
  }

  Future<void> cancelAppointment({required int appointmentId}) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/appointments/$appointmentId/cancel'),
      headers: headers,
      body: jsonEncode({}),
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // fall through
      }
      throw Exception('Failed to cancel appointment');
    }
  }

  Future<Map<String, dynamic>> createAppointment({
    required int doctorId,
    required int patientId,
    required String date,
    required String time,
    required String visitType,
    required String paymentMethod,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/appointments'),
      headers: headers,
      body: jsonEncode({
        'doctor_id': doctorId,
        'patient_id': patientId,
        'appointment_date': date,
        'appointment_time': time,
        'visit_type': visitType,
        'payment_method': paymentMethod,
      }),
    );
    if (res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // Fall through.
      }
      throw Exception('Failed to create appointment');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String> uploadVerificationDocumentBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final headers = await _authorizedHeaders();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/verification-request/upload-document'),
    );
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) {
      throw Exception('Failed to upload document');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['file_url'] ?? '').toString();
  }

  Future<void> createVerificationRequest({
    required int doctorId,
    required String fullName,
    required String dateOfBirth,
    required String qualification,
    required String universityName,
    required int yearOfGraduation,
    required int yearsOfExperience,
    required String specialization,
    required String licenseNumber,
    required String licenseIssuingAuthority,
    required String licenseExpiryDate,
    required String clinicName,
    required String clinicAddress,
    required String city,
    required String area,
    required String pincode,
    required String clinicContactNumber,
    required double consultationFee,
    required bool homeVisitAvailable,
    required double latitude,
    required double longitude,
    String? licenseCertificateUrl,
    String? degreeCertificateUrl,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/verification-request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'doctor_id': doctorId,
        'full_name': fullName,
        'date_of_birth': dateOfBirth,
        'qualification': qualification,
        'university_name': universityName,
        'year_of_graduation': yearOfGraduation,
        'years_of_experience': yearsOfExperience,
        'specialization': specialization,
        'license_number': licenseNumber,
        'license_issuing_authority': licenseIssuingAuthority,
        'license_expiry_date': licenseExpiryDate,
        'clinic_name': clinicName,
        'clinic_address': clinicAddress,
        'city': city,
        'area': area,
        'pincode': pincode,
        'clinic_contact_number': clinicContactNumber,
        'consultation_fee': consultationFee,
        'home_visit_available': homeVisitAvailable ? 1 : 0,
        'latitude': latitude,
        'longitude': longitude,
        'license_certificate_url': licenseCertificateUrl,
        'degree_certificate_url': degreeCertificateUrl,
      }),
    );
    if (res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // Fall through to generic error.
      }
      throw Exception('Failed to submit verification request');
    }
  }

  Future<List<ExerciseLibraryItem>> getExerciseLibrary() async {
    final res = await _client.get(Uri.parse('$_baseUrl/exercises/master'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load exercise library');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => ExerciseLibraryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExerciseLibraryItem> getExerciseLibraryById(int id) async {
    final res = await _client.get(Uri.parse('$_baseUrl/exercises/master/$id'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load exercise detail');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ExerciseLibraryItem.fromJson(data);
  }

  Future<List<VerificationRequest>> getVerificationRequests({
    String? status,
  }) async {
    final statusQuery = status == null ? '' : '?status=$status';
    final res = await _client.get(
      Uri.parse('$_baseUrl/verification-requests$statusQuery'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load verification requests');
    }
    final data = jsonDecode(res.body) as List;
    return data.map((e) => VerificationRequest.fromJson(e)).toList();
  }

  Future<VerificationRequest> getVerificationRequestById(int requestId) async {
    final res = await _client.get(
      Uri.parse('$_baseUrl/verification-request/$requestId'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load verification request');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return VerificationRequest.fromJson(data);
  }

  Future<VerificationRequest> getDoctorProfile(int doctorId) async {
    final res = await _client.get(
      Uri.parse('$_baseUrl/doctors/$doctorId/profile'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load doctor profile');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return VerificationRequest.fromJson(data);
  }

  Future<void> approveVerificationRequest(int requestId) async {
    final res = await _client.put(
      Uri.parse('$_baseUrl/verification-request/$requestId/approve'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to approve request');
    }
  }

  Future<void> rejectVerificationRequest(
    int requestId, {
    required String rejectionReason,
  }) async {
    final res = await _client.put(
      Uri.parse('$_baseUrl/verification-request/$requestId/reject'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rejection_reason': rejectionReason}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to reject request');
    }
  }

  Future<void> removeDoctor(
    int doctorId, {
    required String removedReason,
  }) async {
    final res = await _client.put(
      Uri.parse('$_baseUrl/doctors/$doctorId/remove'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'removed_reason': removedReason}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to remove doctor');
    }
  }

  Future<void> createUserReport({
    required String targetRole,
    int? targetDoctorId,
    int? targetPatientId,
    required String reasonCategory,
    required String description,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.post(
      Uri.parse('$_baseUrl/reports'),
      headers: headers,
      body: jsonEncode({
        'target_role': targetRole,
        'target_doctor_id': targetDoctorId,
        'target_patient_id': targetPatientId,
        'reason_category': reasonCategory,
        'description': description,
      }),
    );
    if (res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // fall through
      }
      throw Exception('Failed to submit report');
    }
  }

  Future<List<UserReport>> getMyReports() async {
    final headers = await _authorizedHeaders();
    final res = await _client.get(
      Uri.parse('$_baseUrl/reports/mine'),
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load reports');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => UserReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserReport>> getAdminReports({
    String? status,
    String? targetRole,
    int? targetDoctorId,
    int? targetPatientId,
  }) async {
    final headers = await _authorizedHeaders();
    final params = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (targetRole != null && targetRole.trim().isNotEmpty) {
      params['target_role'] = targetRole.trim();
    }
    if (targetDoctorId != null) {
      params['target_doctor_id'] = '$targetDoctorId';
    }
    if (targetPatientId != null) {
      params['target_patient_id'] = '$targetPatientId';
    }

    final uri = Uri.parse(
      '$_baseUrl/admin/reports',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to load admin reports');
    }
    final data = jsonDecode(res.body) as List<dynamic>;
    return data
        .map((e) => UserReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateAdminReportStatus({
    required int reportId,
    required String status,
    String? adminNote,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/admin/reports/$reportId'),
      headers: headers,
      body: jsonEncode({'status': status, 'admin_note': adminNote ?? ''}),
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // fall through
      }
      throw Exception('Failed to update report');
    }
  }

  Future<void> updateDoctorPricing({
    required int doctorId,
    required double clinicFee,
    required double homeVisitBaseFee,
    double? perKmCharge,
  }) async {
    final headers = await _authorizedHeaders(
      base: {'Content-Type': 'application/json'},
    );
    final res = await _client.put(
      Uri.parse('$_baseUrl/doctors/$doctorId/pricing'),
      headers: headers,
      body: jsonEncode({
        'clinic_fee': clinicFee,
        'home_visit_base_fee': homeVisitBaseFee,
        'per_km_charge': perKmCharge,
      }),
    );
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          throw Exception(body['message'].toString());
        }
      } catch (_) {
        // Fall through.
      }
      throw Exception('Failed to update doctor pricing');
    }
  }
}
