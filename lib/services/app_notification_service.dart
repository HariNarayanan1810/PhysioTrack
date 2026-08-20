import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_user.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

enum NotificationAudienceRole { admin, doctor, patient, any }

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.audienceRole,
    this.audienceUserId,
    this.audienceDoctorId,
    this.audiencePatientId,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationAudienceRole audienceRole;
  final int? audienceUserId;
  final int? audienceDoctorId;
  final int? audiencePatientId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'audience_role': audienceRole.name,
      'audience_user_id': audienceUserId,
      'audience_doctor_id': audienceDoctorId,
      'audience_patient_id': audiencePatientId,
    };
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    NotificationAudienceRole roleFromJson(dynamic raw) {
      final value = (raw ?? '').toString().toLowerCase();
      return NotificationAudienceRole.values.firstWhere(
        (role) => role.name == value,
        orElse: () => NotificationAudienceRole.any,
      );
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      audienceRole: roleFromJson(json['audience_role']),
      audienceUserId: parseInt(json['audience_user_id']),
      audienceDoctorId: parseInt(json['audience_doctor_id']),
      audiencePatientId: parseInt(json['audience_patient_id']),
    );
  }
}

class AppNotificationService extends ChangeNotifier {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();
  static const String _storageKey = 'app_notifications_v1';
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'physiotrack_alerts',
        'PhysioTrack Alerts',
        description: 'Heads-up alerts for appointments and home visits',
        importance: Importance.max,
      );

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final List<AppNotificationItem> _items = [];

  OverlayEntry? _activeBanner;
  Timer? _bannerTimer;
  bool _initialized = false;

  List<AppNotificationItem> get items => List.unmodifiable(_items);

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      await _loadStored();
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotificationsPlugin.initialize(initSettings);

    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    final macPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    await _loadStored();
    _initialized = true;
  }

  List<AppNotificationItem> notificationsFor(SessionUser? session) {
    if (session == null) return const [];
    return _items.where((item) => _matchesAudience(item, session)).toList();
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationAudienceRole audienceRole,
    int? audienceUserId,
    int? audienceDoctorId,
    int? audiencePatientId,
    bool showBanner = true,
    bool showSystemNotification = true,
  }) async {
    final item = AppNotificationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      message: message,
      createdAt: DateTime.now(),
      audienceRole: audienceRole,
      audienceUserId: audienceUserId,
      audienceDoctorId: audienceDoctorId,
      audiencePatientId: audiencePatientId,
    );

    _items.insert(0, item);
    if (_items.length > 100) {
      _items.removeRange(100, _items.length);
    }
    await _saveStored();
    notifyListeners();

    final session = await _currentSession();
    if (session == null || !_matchesAudience(item, session)) {
      return;
    }

    if (showBanner) {
      _showTopBanner(item);
    }
    if (showSystemNotification && !kIsWeb) {
      await _showLocalNotification(item);
    }
  }

  Future<void> _loadStored() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          data
              .whereType<Map>()
              .map(
                (item) => AppNotificationItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
        );
    } catch (_) {
      _items.clear();
    }
  }

  Future<void> _saveStored() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }

  Future<SessionUser?> _currentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('session_user');
    if (raw == null || raw.isEmpty) return null;
    try {
      return SessionUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool _matchesAudience(AppNotificationItem item, SessionUser session) {
    final roleMatches =
        item.audienceRole == NotificationAudienceRole.any ||
        item.audienceRole.name.toUpperCase() == session.role.toUpperCase();
    if (!roleMatches) return false;
    if (item.audienceUserId != null && item.audienceUserId != session.userId) {
      return false;
    }
    if (item.audienceDoctorId != null &&
        item.audienceDoctorId != session.doctorId) {
      return false;
    }
    if (item.audiencePatientId != null &&
        item.audiencePatientId != session.patientId) {
      return false;
    }
    return true;
  }

  void _showTopBanner(AppNotificationItem item) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _bannerTimer?.cancel();
    _activeBanner?.remove();

    _activeBanner = OverlayEntry(
      builder: (context) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4C5C),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.white,
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        item.message,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        onPressed: _dismissBanner,
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_activeBanner!);
    _bannerTimer = Timer(const Duration(seconds: 5), _dismissBanner);
  }

  void _dismissBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _activeBanner?.remove();
    _activeBanner = null;
  }

  Future<void> _showLocalNotification(AppNotificationItem item) async {
    const androidDetails = AndroidNotificationDetails(
      'physiotrack_alerts',
      'PhysioTrack Alerts',
      channelDescription: 'Heads-up alerts for appointments and home visits',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    try {
      await _localNotificationsPlugin.show(
        item.id.hashCode,
        item.title,
        item.message,
        details,
      );
    } catch (error) {
      debugPrint('Local notification error: $error');
    }
  }
}
