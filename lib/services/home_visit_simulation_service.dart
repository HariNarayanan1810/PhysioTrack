import 'dart:math';

import 'package:flutter/foundation.dart';

import 'app_notification_service.dart';

enum VisitStatus {
  pending,
  inProgress,
  completed,
}

class HomeVisitItem {
  HomeVisitItem({
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.address,
    required this.plannedDurationMinutes,
    this.status = VisitStatus.pending,
    this.estimatedArrival,
    this.actualStartTime,
    this.actualEndTime,
    this.travelMinutes = 0,
  });

  final int appointmentId;
  final int patientId;
  final String patientName;
  final String address;
  final int plannedDurationMinutes;
  VisitStatus status;
  DateTime? estimatedArrival;
  DateTime? actualStartTime;
  DateTime? actualEndTime;
  int travelMinutes;
}

class SimulatedNotification {
  SimulatedNotification({
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String title;
  final String message;
  final DateTime createdAt;
}

class HomeVisitSimulationService extends ChangeNotifier {
  HomeVisitSimulationService._();
  static final HomeVisitSimulationService instance =
      HomeVisitSimulationService._();

  final Random _random = Random();
  final List<HomeVisitItem> _visits = [];

  bool sessionActive = false;
  bool isTrackingEnabled = false;
  int currentPatientIndex = -1;
  DateTime? dayStartedAt;

  List<HomeVisitItem> get visits => List.unmodifiable(_visits);

  void setVisits(List<HomeVisitItem> items) {
    _visits
      ..clear()
      ..addAll(items);
    for (final v in _visits) {
      if (v.travelMinutes <= 0) {
        v.travelMinutes = 10 + _random.nextInt(11);
      }
    }
    sessionActive = false;
    isTrackingEnabled = false;
    currentPatientIndex = _visits.isEmpty ? -1 : 0;
    dayStartedAt = null;
    _recalculateEtas();
    notifyListeners();
  }

  void startDaySession() {
    if (_visits.isEmpty) return;
    sessionActive = true;
    isTrackingEnabled = true;
    dayStartedAt = DateTime.now();
    currentPatientIndex = _firstPendingIndex();
    _recalculateEtas();
    _pushNotification(
      'Doctor started today\'s visits',
      'ETA calculated for upcoming patients.',
    );
    notifyListeners();
  }

  bool startPatientSession(int index) {
    if (!sessionActive || index < 0 || index >= _visits.length) return false;
    final item = _visits[index];
    if (item.status != VisitStatus.pending) return false;
    item.status = VisitStatus.inProgress;
    item.actualStartTime = DateTime.now();
    item.estimatedArrival = null;
    isTrackingEnabled = false;
    currentPatientIndex = index;
    _pushNotification(
      'Session started',
      'Session started for ${item.patientName}.',
    );
    _recalculateEtas();
    notifyListeners();
    return true;
  }

  bool finishPatientSession(int index) {
    if (!sessionActive || index < 0 || index >= _visits.length) return false;
    final item = _visits[index];
    if (item.status != VisitStatus.inProgress) return false;
    item.status = VisitStatus.completed;
    item.actualEndTime = DateTime.now();
    final next = _firstPendingIndex();
    currentPatientIndex = next;
    isTrackingEnabled = next != -1;
    _recalculateEtas();

    if (next != -1) {
      _pushNotification(
        'Next patient alert',
        'Doctor is heading to ${_visits[next].patientName}.',
      );
    } else {
      _pushNotification(
        'Day visits completed',
        'All home visit sessions are completed.',
      );
    }
    notifyListeners();
    return true;
  }

  HomeVisitItem? findVisitByPatientId(int patientId) {
    for (final visit in _visits) {
      if (visit.patientId == patientId) return visit;
    }
    return null;
  }

  String patientArrivalStatus(int patientId) {
    final visit = findVisitByPatientId(patientId);
    if (visit == null) return 'Doctor Starting Visits';
    switch (visit.status) {
      case VisitStatus.completed:
        return 'Visit Completed';
      case VisitStatus.inProgress:
        return 'Doctor In Session';
      case VisitStatus.pending:
        if (sessionActive && isTrackingEnabled) return 'Doctor On The Way';
        return 'Doctor Starting Visits';
    }
  }

  String? patientEtaText(int patientId) {
    final visit = findVisitByPatientId(patientId);
    final eta = visit?.estimatedArrival;
    if (eta == null) return null;
    final hour = eta.hour.toString().padLeft(2, '0');
    final minute = eta.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _recalculateEtas() {
    DateTime cursor = dayStartedAt ?? DateTime.now();
    for (final visit in _visits) {
      if (visit.status == VisitStatus.completed && visit.actualEndTime != null) {
        visit.estimatedArrival = null;
        cursor = visit.actualEndTime!;
        continue;
      }

      if (visit.status == VisitStatus.inProgress) {
        visit.estimatedArrival = null;
        final start = visit.actualStartTime ?? DateTime.now();
        cursor = start.add(Duration(minutes: visit.plannedDurationMinutes));
        continue;
      }

      cursor = cursor.add(Duration(minutes: visit.travelMinutes));
      visit.estimatedArrival = cursor;
      cursor = cursor.add(Duration(minutes: visit.plannedDurationMinutes));
    }
  }

  int _firstPendingIndex() {
    for (var i = 0; i < _visits.length; i++) {
      if (_visits[i].status == VisitStatus.pending) return i;
    }
    return -1;
  }

  void _pushNotification(String title, String message) {
    AppNotificationService.instance.addNotification(
      title: title,
      message: message,
      audienceRole: NotificationAudienceRole.patient,
    );
    debugPrint('[SimNotification] $title - $message');
  }
}
