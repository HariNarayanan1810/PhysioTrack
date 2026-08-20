import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientClinicMapArgs {
  const PatientClinicMapArgs({
    required this.doctorName,
    required this.clinicName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
  });

  final String doctorName;
  final String clinicName;
  final double latitude;
  final double longitude;
  final String address;
  final String city;
}

class PatientClinicMapPage extends StatefulWidget {
  const PatientClinicMapPage({super.key});

  @override
  State<PatientClinicMapPage> createState() => _PatientClinicMapPageState();
}

class _PatientClinicMapPageState extends State<PatientClinicMapPage> {
  GoogleMapController? _mapController;
  LatLng? _patientLocation;
  String? _locationError;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Enable location service to view your current position.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Location permission denied.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _patientLocation = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final rawArgs = ModalRoute.of(context)?.settings.arguments;
        if (rawArgs is PatientClinicMapArgs) {
          _fitBounds(rawArgs);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationError = 'Failed to get current location.';
      });
    }
  }

  Future<void> _openDirections(PatientClinicMapArgs args) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${args.latitude},${args.longitude}&travelmode=driving',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open directions')),
      );
    }
  }

  Set<Marker> _buildMarkers(PatientClinicMapArgs args) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('clinic'),
        position: LatLng(args.latitude, args.longitude),
        infoWindow: InfoWindow(
          title: args.clinicName,
          snippet: args.address.isNotEmpty ? args.address : args.city,
        ),
      ),
    };

    if (_patientLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('patient'),
          position: _patientLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Your Current Location'),
        ),
      );
    }
    return markers;
  }

  void _fitBounds(PatientClinicMapArgs args) {
    final patient = _patientLocation;
    if (_mapController == null || patient == null) return;

    final southWest = LatLng(
      patient.latitude < args.latitude ? patient.latitude : args.latitude,
      patient.longitude < args.longitude ? patient.longitude : args.longitude,
    );
    final northEast = LatLng(
      patient.latitude > args.latitude ? patient.latitude : args.latitude,
      patient.longitude > args.longitude ? patient.longitude : args.longitude,
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: southWest, northeast: northEast),
        70,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs is! PatientClinicMapArgs) {
      return Scaffold(
        appBar: AppBar(title: const Text('Clinic Location')),
        body: const Center(child: Text('Clinic map details not available')),
      );
    }

    final args = rawArgs;
    final clinicLocation = LatLng(args.latitude, args.longitude);

    return Scaffold(
      appBar: AppBar(title: const Text('Clinic Location')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: clinicLocation,
                zoom: 15,
              ),
              myLocationEnabled: _patientLocation != null,
              myLocationButtonEnabled: true,
              markers: _buildMarkers(args),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_patientLocation != null) {
                  _fitBounds(args);
                }
              },
            ),
          ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    args.clinicName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Doctor: ${args.doctorName}'),
                  if (args.city.isNotEmpty) Text('City: ${args.city}'),
                  if (args.address.isNotEmpty) Text('Address: ${args.address}'),
                  const SizedBox(height: 8),
                  if (_loadingLocation)
                    const LinearProgressIndicator()
                  else if (_locationError != null)
                    Text(
                      _locationError!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.red),
                    )
                  else
                    const Text('Your current location is shown on the map.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _openDirections(args),
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Get Directions'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
