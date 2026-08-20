import 'dart:async';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../utils/google_maps_keys.dart';
import '../../utils/polyline_decoder.dart';

class PatientLiveTrackingPage extends StatefulWidget {
  const PatientLiveTrackingPage({super.key});

  @override
  State<PatientLiveTrackingPage> createState() => _PatientLiveTrackingPageState();
}

class _PatientLiveTrackingPageState extends State<PatientLiveTrackingPage> {
  final ApiService _api = ApiService();

  Timer? _pollTimer;
  GoogleMapController? _mapController;
  int? _patientId;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _tracking;
  List<LatLng> _routePoints = const [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final session = await SessionService().getSession();
    final patientId = session?.patientId;
    if (patientId == null) {
      setState(() {
        _loading = false;
        _error = 'Patient session not found';
      });
      return;
    }
    _patientId = patientId;
    await _fetchTracking();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchTracking();
    });
  }

  Future<void> _fetchTracking() async {
    final patientId = _patientId;
    if (patientId == null) return;
    try {
      final tracking = await _api.getPatientHomeVisitTracking(patientId);
      await _updateRoutePolyline(tracking);
      if (!mounted) return;
      setState(() {
        _tracking = tracking;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshBounds();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load live tracking';
      });
    }
  }

  String _statusText() {
    final status = (_tracking?['status'] ?? '').toString().toUpperCase();
    final liveTrackingEnabled =
        _tracking?['live_tracking_enabled'] == true ||
        _tracking?['live_tracking_enabled'] == 1;
    if (liveTrackingEnabled && status == 'APPROVED') return 'Doctor On The Way';
    if (status == 'IN_PROGRESS') return 'Doctor In Session';
    if (status == 'COMPLETED') return 'Visit Completed';
    if (status == 'APPROVED') return 'Doctor Starting Visits';
    return 'No live home visit available';
  }

  String _etaText() {
    final etaRaw = _tracking?['current_eta_minutes'];
    final eta = etaRaw is int ? etaRaw : int.tryParse('$etaRaw');
    if (eta == null) return '--';
    return '$eta min';
  }

  Set<Marker> _buildMarkers() {
    final tracking = _tracking;
    if (tracking == null) return const {};

    final markers = <Marker>{};
    final patientLat = _toDouble(tracking['patient_latitude']);
    final patientLng = _toDouble(tracking['patient_longitude']);
    final doctorLat = _toDouble(tracking['doctor_live_latitude']);
    final doctorLng = _toDouble(tracking['doctor_live_longitude']);

    if (patientLat != null && patientLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('patient-home'),
          position: LatLng(patientLat, patientLng),
          infoWindow: const InfoWindow(title: 'Your Home'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    if (doctorLat != null && doctorLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('doctor-live'),
          position: LatLng(doctorLat, doctorLng),
          infoWindow: InfoWindow(
            title: (_tracking?['doctor_name'] ?? 'Doctor').toString(),
            snippet: 'Live location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final tracking = _tracking;
    if (tracking == null) return const {};
    final patientLat = _toDouble(tracking['patient_latitude']);
    final patientLng = _toDouble(tracking['patient_longitude']);
    final doctorLat = _toDouble(tracking['doctor_live_latitude']);
    final doctorLng = _toDouble(tracking['doctor_live_longitude']);
    if (patientLat == null ||
        patientLng == null ||
        doctorLat == null ||
        doctorLng == null) {
      return const {};
    }

    if (_routePoints.length < 2) {
      return const {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('doctor-route'),
        points: _routePoints,
        color: Colors.blue,
        width: 5,
      ),
    };
  }

  Future<void> _updateRoutePolyline(Map<String, dynamic>? tracking) async {
    final patientLat = _toDouble(tracking?['patient_latitude']);
    final patientLng = _toDouble(tracking?['patient_longitude']);
    final doctorLat = _toDouble(tracking?['doctor_live_latitude']);
    final doctorLng = _toDouble(tracking?['doctor_live_longitude']);

    if (tracking == null ||
        patientLat == null ||
        patientLng == null ||
        doctorLat == null ||
        doctorLng == null) {
      if (mounted) {
        setState(() => _routePoints = const []);
      } else {
        _routePoints = const [];
      }
      return;
    }

    List<LatLng> points = const [];

    try {
      final directions = await _api.getDirections(
        originLatitude: doctorLat,
        originLongitude: doctorLng,
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
        originLatitude: doctorLat,
        originLongitude: doctorLng,
        destinationLatitude: patientLat,
        destinationLongitude: patientLng,
      );
    }

    if (points.length < 2) {
      points = [
        LatLng(doctorLat, doctorLng),
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

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _refreshBounds() {
    final controller = _mapController;
    final tracking = _tracking;
    if (controller == null || tracking == null) return;

    final points = <LatLng>[];
    final patientLat = _toDouble(tracking['patient_latitude']);
    final patientLng = _toDouble(tracking['patient_longitude']);
    final doctorLat = _toDouble(tracking['doctor_live_latitude']);
    final doctorLng = _toDouble(tracking['doctor_live_longitude']);

    if (patientLat != null && patientLng != null) {
      points.add(LatLng(patientLat, patientLng));
    }
    if (doctorLat != null && doctorLng != null) {
      points.add(LatLng(doctorLat, doctorLng));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _tracking == null
                  ? const Center(child: Text('No live home visit available for today'))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Current Status: ${_statusText()}'),
                                  const SizedBox(height: 6),
                                  Text('Estimated Arrival: ${_etaText()}'),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Doctor: ${(_tracking?['doctor_name'] ?? '').toString()}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                    _toDouble(_tracking?['patient_latitude']) ?? 11.0168,
                                    _toDouble(_tracking?['patient_longitude']) ?? 76.9558,
                                  ),
                                  zoom: 14,
                                ),
                                markers: _buildMarkers(),
                                polylines: _buildPolylines(),
                                onMapCreated: (controller) {
                                  _mapController = controller;
                                  _refreshBounds();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
