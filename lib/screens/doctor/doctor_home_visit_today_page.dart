import 'dart:async';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/api_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/session_service.dart';
import '../../utils/google_maps_keys.dart';
import '../../utils/polyline_decoder.dart';

class DoctorHomeVisitTodayPage extends StatefulWidget {
  const DoctorHomeVisitTodayPage({super.key});

  @override
  State<DoctorHomeVisitTodayPage> createState() =>
      _DoctorHomeVisitTodayPageState();
}

class _HomeVisitViewItem {
  const _HomeVisitViewItem({
    required this.appointment,
    required this.patient,
  });

  final Appointment appointment;
  final Patient patient;
}

class _SpecialSessionInput {
  const _SpecialSessionInput({
    required this.isSpecialSession,
    this.specialFeeAmount,
    this.specialFeeReason,
  });

  final bool isSpecialSession;
  final double? specialFeeAmount;
  final String? specialFeeReason;
}

class _DoctorHomeVisitTodayPageState extends State<DoctorHomeVisitTodayPage> {
  static const LatLng _fallbackCenter = LatLng(11.0168, 76.9558);
  static const int _routeOptimizationTimeToleranceMinutes = 45;

  final ApiService _api = ApiService();

  bool _loading = true;
  bool _startingDay = false;
  bool _mapOpen = false;
  bool _daySessionStarted = false;
  String? _error;

  List<_HomeVisitViewItem> _visits = const [];
  StreamSubscription<Position>? _positionSubscription;
  GoogleMapController? _mapController;
  LatLng? _doctorLocation;
  int? _trackedAppointmentId;
  List<LatLng> _routePoints = const [];

  @override
  void initState() {
    super.initState();
    _loadTodayVisits();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  bool _isToday(String rawDate) {
    final now = DateTime.now();
    final parts = rawDate.split('-');
    if (parts.length == 3) {
      if (parts[0].length == 2 && parts[2].length == 4) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        return day == now.day && month == now.month && year == now.year;
      }
      if (parts[0].length == 4) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        return day == now.day && month == now.month && year == now.year;
      }
    }
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return false;
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  int _parseTimeAsMinutes(String raw) {
    final value = raw.trim().toUpperCase();
    final reg = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$');
    final match = reg.firstMatch(value);
    if (match == null) return 0;
    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final suffix = match.group(3) ?? '';
    if (suffix == 'PM' && hour < 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  DateTime? _parseBackendDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--';
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _loadTodayVisits() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await SessionService().getSession();
      final doctorId = session?.doctorId;
      if (doctorId == null) {
        setState(() {
          _loading = false;
          _error = 'Doctor session not found';
        });
        return;
      }

      final appointments = await _api.getAppointments(doctorId: doctorId);
      final patients = await _api.getPatients(doctorId: doctorId);
      final patientById = {for (final patient in patients) patient.id: patient};

      final homeVisits = appointments
          .where(
            (appointment) =>
                appointment.visitType.toUpperCase() == 'HOME' &&
                _isToday(appointment.appointmentDate) &&
                {'APPROVED', 'IN_PROGRESS', 'COMPLETED'}
                    .contains(appointment.status.toUpperCase()) &&
                patientById.containsKey(appointment.patientId),
          )
          .toList()
        ..sort(
          (a, b) => _parseTimeAsMinutes(a.appointmentTime)
              .compareTo(_parseTimeAsMinutes(b.appointmentTime)),
        );

      final items = homeVisits
          .map(
            (appointment) => _HomeVisitViewItem(
              appointment: appointment,
              patient: patientById[appointment.patientId]!,
            ),
          )
          .toList();

      setState(() {
        _visits = items;
        _daySessionStarted = items.any(
          (item) =>
              item.appointment.status.toUpperCase() == 'IN_PROGRESS' ||
              item.appointment.liveTrackingEnabled,
        );
        _trackedAppointmentId = _findNextTrackableAppointmentId(items);
        _loading = false;
      });
      await _updateRoutePolyline();

      if (_daySessionStarted) {
        await _ensureLocationTracking();
      }
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Failed to load home visits';
      });
    }
  }

  int? _findNextTrackableAppointmentId(List<_HomeVisitViewItem> items) {
    final hasActiveSession = items.any(
      (item) => item.appointment.status.toUpperCase() == 'IN_PROGRESS',
    );
    if (hasActiveSession) {
      return null;
    }

    final pendingVisits = items
        .where((item) => item.appointment.status.toUpperCase() == 'APPROVED')
        .toList();
    if (pendingVisits.isEmpty) return null;

    final doctorLocation = _doctorLocation;
    if (doctorLocation == null) {
      return pendingVisits.first.appointment.id;
    }

    final earliestTime = pendingVisits
        .map((item) => _parseTimeAsMinutes(item.appointment.appointmentTime))
        .reduce((a, b) => a < b ? a : b);

    final candidateVisits = pendingVisits.where((item) {
      final scheduledMinutes = _parseTimeAsMinutes(item.appointment.appointmentTime);
      return scheduledMinutes <=
          earliestTime + _routeOptimizationTimeToleranceMinutes;
    }).toList();

    final rankedCandidates = candidateVisits.isEmpty ? pendingVisits : candidateVisits;

    rankedCandidates.sort((a, b) {
      final distanceA = _distanceFromDoctorMeters(a, doctorLocation);
      final distanceB = _distanceFromDoctorMeters(b, doctorLocation);
      final compareDistance = distanceA.compareTo(distanceB);
      if (compareDistance != 0) return compareDistance;

      final timeA = _parseTimeAsMinutes(a.appointment.appointmentTime);
      final timeB = _parseTimeAsMinutes(b.appointment.appointmentTime);
      return timeA.compareTo(timeB);
    });

    for (final item in rankedCandidates) {
      if (_hasValidCoordinates(item)) {
        return item.appointment.id;
      }
    }

    return pendingVisits.first.appointment.id;
  }

  bool _hasValidCoordinates(_HomeVisitViewItem item) {
    return item.patient.latitude != null && item.patient.longitude != null;
  }

  double _distanceFromDoctorMeters(_HomeVisitViewItem item, LatLng doctorLocation) {
    final lat = item.patient.latitude;
    final lng = item.patient.longitude;
    if (lat == null || lng == null) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      doctorLocation.latitude,
      doctorLocation.longitude,
      lat,
      lng,
    );
  }

  _HomeVisitViewItem? _trackedVisit() {
    final trackedId = _trackedAppointmentId;
    if (trackedId == null) return null;
    for (final item in _visits) {
      if (item.appointment.id == trackedId) return item;
    }
    return null;
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable GPS/location service')),
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return false;
    }
    return true;
  }

  Future<void> _ensureLocationTracking() async {
    final allowed = await _ensureLocationPermission();
    if (!allowed) return;

    _positionSubscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((position) async {
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _doctorLocation = location;
        if (!_visits.any(
          (item) => item.appointment.status.toUpperCase() == 'IN_PROGRESS',
        )) {
          _trackedAppointmentId = _findNextTrackableAppointmentId(_visits);
        }
      });
      await _pushLiveTrackingUpdate();
      await _updateRoutePolyline();
      _refreshMapBounds();
    });

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _doctorLocation = LatLng(position.latitude, position.longitude);
        if (!_visits.any(
          (item) => item.appointment.status.toUpperCase() == 'IN_PROGRESS',
        )) {
          _trackedAppointmentId = _findNextTrackableAppointmentId(_visits);
        }
      });
      await _pushLiveTrackingUpdate();
      await _updateRoutePolyline();
      _refreshMapBounds();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch current location')),
      );
    }
  }

  int? _estimatedEtaMinutes(_HomeVisitViewItem item) {
    final doctorLocation = _doctorLocation;
    final patientLat = item.patient.latitude;
    final patientLng = item.patient.longitude;
    if (doctorLocation == null || patientLat == null || patientLng == null) {
      return null;
    }
    final distanceMeters = Geolocator.distanceBetween(
      doctorLocation.latitude,
      doctorLocation.longitude,
      patientLat,
      patientLng,
    );
    final eta = (distanceMeters / 416.67).ceil();
    return eta < 1 ? 1 : eta;
  }

  Future<void> _pushLiveTrackingUpdate() async {
    final tracked = _trackedVisit();
    final doctorLocation = _doctorLocation;
    if (!_daySessionStarted || tracked == null || doctorLocation == null) {
      return;
    }

    try {
      await _api.updateHomeVisitLiveTracking(
        appointmentId: tracked.appointment.id,
        latitude: doctorLocation.latitude,
        longitude: doctorLocation.longitude,
        etaMinutes: _estimatedEtaMinutes(tracked),
      );
    } catch (_) {
      // Keep UI responsive; doctor can continue even if one tracking update fails.
    }
  }

  Future<void> _startDay() async {
    setState(() => _startingDay = true);
    try {
      await _loadTodayVisits();
      if (!mounted) return;
      setState(() {
        _daySessionStarted = true;
        _trackedAppointmentId = _findNextTrackableAppointmentId(_visits);
      });
      await _ensureLocationTracking();
      await _updateRoutePolyline();
      final nextVisit = _trackedVisit();
      await AppNotificationService.instance.addNotification(
        title: 'Home visit day started',
        message: 'Live tracking is active for today\'s home visits.',
        audienceRole: NotificationAudienceRole.doctor,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today\'s home visit session started')),
      );
    } finally {
      if (mounted) setState(() => _startingDay = false);
    }
  }

  Future<void> _stopDay() async {
    try {
      await _api.stopDoctorHomeVisitDay();
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      if (!mounted) return;
      setState(() {
        _daySessionStarted = false;
        _trackedAppointmentId = null;
        _routePoints = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today\'s home visit session stopped')),
      );
      await _loadTodayVisits();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _updateVisitStatus(_HomeVisitViewItem item, String status) async {
    _SpecialSessionInput? specialSession;
    if (status == 'COMPLETED') {
      specialSession = await _showSpecialFeeDialog(item);
      if (!mounted || specialSession == null) return;
    }

    try {
      await _api.updateAppointmentStatus(
        appointmentId: item.appointment.id,
        status: status,
        isSpecialSession: specialSession?.isSpecialSession ?? false,
        specialFeeAmount: specialSession?.specialFeeAmount,
        specialFeeReason: specialSession?.specialFeeReason,
      );
      await _loadTodayVisits();
      if (!mounted) return;

      if (status == 'IN_PROGRESS') {
        setState(() {
          _trackedAppointmentId = _findNextTrackableAppointmentId(_visits);
        });
        await AppNotificationService.instance.addNotification(
          title: 'Patient session started',
          message: 'Session started for ${item.appointment.patientName}.',
          audienceRole: NotificationAudienceRole.doctor,
        );
      } else if (status == 'COMPLETED') {
        setState(() {
          _trackedAppointmentId = _findNextTrackableAppointmentId(_visits);
        });
        await _pushLiveTrackingUpdate();
        await AppNotificationService.instance.addNotification(
          title: 'Session completed',
          message: 'Session completed for ${item.appointment.patientName}.',
          audienceRole: NotificationAudienceRole.doctor,
        );
      }
      await _updateRoutePolyline();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'IN_PROGRESS'
                ? 'Session started for ${item.appointment.patientName}'
                : 'Session completed for ${item.appointment.patientName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<_SpecialSessionInput?> _showSpecialFeeDialog(
    _HomeVisitViewItem item,
  ) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isSpecial = false;
    String? localError;

    final result = await showDialog<_SpecialSessionInput>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Finish ${item.appointment.patientName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current session fee: Rs ${(item.appointment.sessionFee ?? 0).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: isSpecial,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Add special treatment charge'),
                    subtitle: const Text(
                      'Use only if this patient required extra treatment such as cupping or needling.',
                    ),
                    onChanged: (value) {
                      setStateDialog(() {
                        isSpecial = value ?? false;
                        localError = null;
                      });
                    },
                  ),
                  if (isSpecial) ...[
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Special charge amount',
                        hintText: 'Example: 180',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Example: Needling therapy',
                      ),
                    ),
                  ],
                  if (localError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!isSpecial) {
                      Navigator.pop(
                        context,
                        const _SpecialSessionInput(isSpecialSession: false),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountCtrl.text.trim());
                    final reason = reasonCtrl.text.trim();
                    if (amount == null || amount < 0) {
                      setStateDialog(() {
                        localError = 'Enter a valid special charge amount';
                      });
                      return;
                    }
                    if (reason.isEmpty) {
                      setStateDialog(() {
                        localError = 'Enter a short reason for the extra charge';
                      });
                      return;
                    }

                    Navigator.pop(
                      context,
                      _SpecialSessionInput(
                        isSpecialSession: true,
                        specialFeeAmount: amount,
                        specialFeeReason: reason,
                      ),
                    );
                  },
                  child: const Text('Finish Session'),
                ),
              ],
            );
          },
        );
      },
    );

    amountCtrl.dispose();
    reasonCtrl.dispose();
    return result;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    if (_doctorLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('doctor'),
          position: _doctorLocation!,
          infoWindow: const InfoWindow(title: 'Doctor Current Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    for (final item in _visits) {
      final lat = item.patient.latitude;
      final lng = item.patient.longitude;
      if (lat == null || lng == null) continue;
      final isTracked = item.appointment.id == _trackedAppointmentId;
      markers.add(
        Marker(
          markerId: MarkerId('patient-${item.appointment.id}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isTracked ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: item.appointment.patientName,
            snippet: item.patient.address,
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final tracked = _trackedVisit();
    final doctorLocation = _doctorLocation;
    final patientLat = tracked?.patient.latitude;
    final patientLng = tracked?.patient.longitude;
    if (tracked == null ||
        doctorLocation == null ||
        patientLat == null ||
        patientLng == null) {
      return const {};
    }

    if (_routePoints.length < 2) {
      return const {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('current-route'),
        width: 5,
        color: Colors.blue,
        points: _routePoints,
      ),
    };
  }

  Future<void> _updateRoutePolyline() async {
    final tracked = _trackedVisit();
    final doctorLocation = _doctorLocation;
    final patientLat = tracked?.patient.latitude;
    final patientLng = tracked?.patient.longitude;

    if (tracked == null ||
        doctorLocation == null ||
        patientLat == null ||
        patientLng == null) {
      if (mounted) {
        setState(() => _routePoints = const []);
      }
      return;
    }

    List<LatLng> points = const [];

    try {
      final directions = await _api.getDirections(
        originLatitude: doctorLocation.latitude,
        originLongitude: doctorLocation.longitude,
        destinationLatitude: patientLat,
        destinationLongitude: patientLng,
      );
      final encoded = (directions['polyline'] ?? '').toString();
      final decoded = decodeGooglePolyline(encoded);
      if (decoded.length >= 2) {
        points = decoded;
      }
    } catch (_) {
      // Fall back to direct polyline request below.
    }

    if (points.length < 2) {
      points = await _fetchDirectRoadRoute(
        originLatitude: doctorLocation.latitude,
        originLongitude: doctorLocation.longitude,
        destinationLatitude: patientLat,
        destinationLongitude: patientLng,
      );
    }

    if (points.length < 2) {
      points = [
        LatLng(doctorLocation.latitude, doctorLocation.longitude),
        LatLng(patientLat, patientLng),
      ];
    }

    if (!mounted) return;
    setState(() {
      _routePoints = points.length >= 2 ? points : const [];
    });
  }

  Future<List<LatLng>> _fetchDirectRoadRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      final result = await PolylinePoints.legacy(
        kGoogleMapsRouteApiKey,
      ).getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(originLatitude, originLongitude),
          destination: PointLatLng(
            destinationLatitude,
            destinationLongitude,
          ),
          mode: TravelMode.driving,
        ),
      );
      if (result.points.length < 2) return const [];
      return result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  void _refreshMapBounds() {
    final controller = _mapController;
    if (controller == null) return;
    final points = <LatLng>[];
    if (_doctorLocation != null) points.add(_doctorLocation!);
    for (final item in _visits) {
      final lat = item.patient.latitude;
      final lng = item.patient.longitude;
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }
    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        70,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'APPROVED':
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COMPLETED':
        return 'Completed';
      case 'APPROVED':
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today Home Visits')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadTodayVisits,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  _visits.isEmpty || _startingDay ? null : _startDay,
                              child: Text(
                                _startingDay
                                    ? 'Loading...'
                                    : _daySessionStarted
                                        ? 'Refresh Today\'s Session'
                                        : 'Start Today\'s Session',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_daySessionStarted)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: OutlinedButton(
                                onPressed: _stopDay,
                                child: const Text('Stop Session'),
                              ),
                            ),
                          OutlinedButton(
                            onPressed: () {
                              setState(() => _mapOpen = !_mapOpen);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _refreshMapBounds();
                              });
                            },
                            child: Text(_mapOpen ? 'Close Map' : 'Open Map'),
                          ),
                        ],
                      ),
                      if (_mapOpen) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 280,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _doctorLocation ?? _fallbackCenter,
                                zoom: 13,
                              ),
                              myLocationEnabled: _doctorLocation != null,
                              myLocationButtonEnabled: true,
                              markers: _buildMarkers(),
                              polylines: _buildPolylines(),
                              onMapCreated: (controller) {
                                _mapController = controller;
                                _refreshMapBounds();
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_visits.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No approved home visits available for today'),
                          ),
                        )
                      else
                        ..._visits.map((item) {
                          final status = item.appointment.status.toUpperCase();
                          final eta = item.appointment.id == _trackedAppointmentId
                              ? _estimatedEtaMinutes(item)
                              : item.appointment.currentEtaMinutes;
                          final actualStart = _parseBackendDateTime(
                            item.appointment.actualStartTime,
                          );
                          final actualEnd = _parseBackendDateTime(
                            item.appointment.actualEndTime,
                          );

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.appointment.patientName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            color: _statusColor(status),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(item.patient.address),
                                  Text(
                                    'Scheduled Time: ${item.appointment.appointmentTime}',
                                  ),
                                  Text(
                                    'Planned Duration: 30 min',
                                  ),
                                  if (item.appointment.sessionFee != null)
                                    Text(
                                      'Session Fee: Rs ${item.appointment.sessionFee!.toStringAsFixed(2)}',
                                    ),
                                  if (eta != null && status == 'APPROVED')
                                    Text('Doctor will arrive within $eta min'),
                                  if (item.appointment.isSpecialSession &&
                                      item.appointment.specialFeeAmount != null)
                                    Text(
                                      'Special Charge: Rs ${item.appointment.specialFeeAmount!.toStringAsFixed(2)}'
                                      '${item.appointment.specialFeeReason?.isNotEmpty == true ? ' (${item.appointment.specialFeeReason})' : ''}',
                                    ),
                                  if (actualStart != null)
                                    Text('Actual Start: ${_formatTime(actualStart)}'),
                                  if (actualEnd != null)
                                    Text('Actual End: ${_formatTime(actualEnd)}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: status == 'APPROVED'
                                              ? () => _updateVisitStatus(
                                                    item,
                                                    'IN_PROGRESS',
                                                  )
                                              : null,
                                          child: const Text('Start Session'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: status == 'IN_PROGRESS'
                                              ? () => _updateVisitStatus(
                                                    item,
                                                    'COMPLETED',
                                                  )
                                              : null,
                                          child: const Text('Finish Session'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
