import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/session_user.dart';
import 'api_service.dart';
import 'app_notification_service.dart';
import 'session_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      syncTokenWithBackend();
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _saveIncomingMessage(initialMessage, showSystemNotification: false);
    }

    _initialized = true;
  }

  Future<void> syncTokenWithBackend() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final session = await SessionService().getSession();
    if (currentUser == null || session == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await ApiService().registerDeviceToken(
        fcmToken: token,
        platform: _platformLabel(),
      );
    } catch (_) {
      // Keep login/startup resilient if FCM registration is unavailable.
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _saveIncomingMessage(message, showSystemNotification: false);
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    await _saveIncomingMessage(message, showBanner: false, showSystemNotification: false);
  }

  Future<void> _saveIncomingMessage(
    RemoteMessage message, {
    bool showBanner = true,
    bool showSystemNotification = true,
  }) async {
    final session = await SessionService().getSession();
    final title =
        message.notification?.title ??
        message.data['title'] ??
        'PhysioTrack Notification';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        'You have a new notification.';

    final audienceRole = _audienceForSession(session);
    await AppNotificationService.instance.addNotification(
      title: title,
      message: body,
      audienceRole: audienceRole,
      audienceUserId: session?.userId,
      audienceDoctorId: session?.doctorId,
      audiencePatientId: session?.patientId,
      showBanner: showBanner,
      showSystemNotification: showSystemNotification,
    );
  }

  NotificationAudienceRole _audienceForSession(SessionUser? session) {
    final role = session?.role.toUpperCase();
    if (role == 'ADMIN') return NotificationAudienceRole.admin;
    if (role == 'DOCTOR') return NotificationAudienceRole.doctor;
    if (role == 'PATIENT') return NotificationAudienceRole.patient;
    return NotificationAudienceRole.any;
  }
}
