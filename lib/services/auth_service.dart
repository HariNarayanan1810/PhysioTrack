import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/session_user.dart';
import 'fcm_service.dart';
import 'session_service.dart';

class AuthService {
  static const String _webBaseUrl = 'http://localhost:4000';
  // static const String _androidBaseUrl = 'http://10.0.2.2:4000';
  //static const String _androidBaseUrl = 'http://--wireless lan adapter wifi ipv4 address';
  static const String _androidBaseUrl = 'http://192.168.1.6:4000';

  String get _baseUrl => kIsWeb ? _webBaseUrl : _androidBaseUrl;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final SessionService _sessionService = SessionService();

  Future<void> signupAndRegister({
    required String email,
    required String password,
    required String role,
    String? name,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Firebase signup failed');

    final cleanedName = (name ?? '').trim();
    if (cleanedName.isNotEmpty) {
      await user.updateDisplayName(cleanedName);
    }

    final token = await user.getIdToken(true);
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'role': role.toUpperCase(),
        'name': name?.trim() ?? '',
      }),
    );

    if (response.statusCode != 201) {
      await _firebaseAuth.signOut();
      throw Exception('Backend register failed: ${response.body}');
    }

    await _firebaseAuth.signOut();
    await _sessionService.clearSession();
  }

  Future<Map<String, dynamic>> loginAndFetchProfile({
    required String email,
    required String password,
    required String role,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Firebase login failed');

    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'role': role.toUpperCase()}),
    );
    if (response.statusCode != 200) {
      throw Exception('Backend login failed ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final returnedRole = (data['role'] ?? '').toString().toUpperCase();
    if (returnedRole != role.toUpperCase()) {
      throw Exception('Role mismatch for selected login');
    }
    final session = SessionUser.fromJson(data);
    await _sessionService.saveSession(session);
    await FcmService.instance.syncTokenWithBackend();
    return data;
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _sessionService.clearSession();
  }
}
