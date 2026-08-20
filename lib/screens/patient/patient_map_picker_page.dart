import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerResult {
  const MapPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.state,
  });

  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
}

class PatientMapPickerPage extends StatefulWidget {
  const PatientMapPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<PatientMapPickerPage> createState() => _PatientMapPickerPageState();
}

class _PatientMapPickerPageState extends State<PatientMapPickerPage> {
  static const LatLng _defaultCenter = LatLng(11.0168, 76.9558);

  GoogleMapController? _mapController;
  late LatLng _selected;
  String _address = '';
  String _city = '';
  String _state = '';
  bool _loadingAddress = false;
  bool _loadingCurrentLocation = false;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(
      widget.initialLatitude ?? _defaultCenter.latitude,
      widget.initialLongitude ?? _defaultCenter.longitude,
    );
    _resolveAddress(_selected);
  }

  Future<void> _resolveAddress(LatLng latLng) async {
    setState(() => _loadingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (!mounted) return;
      if (placemarks.isEmpty) {
        setState(() {
          _address = '';
          _city = '';
          _state = '';
          _loadingAddress = false;
        });
        return;
      }

      final p = placemarks.first;
      final parts = <String>[
        p.name ?? '',
        p.street ?? '',
        p.subLocality ?? '',
        p.locality ?? '',
        p.administrativeArea ?? '',
        p.postalCode ?? '',
      ].where((e) => e.trim().isNotEmpty).toList();

      setState(() {
        _address = parts.join(', ');
        _city = (p.locality ?? '').trim();
        _state = (p.administrativeArea ?? '').trim();
        _loadingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAddress = false);
    }
  }

  void _onSelected(LatLng latLng) {
    setState(() => _selected = latLng);
    _resolveAddress(latLng);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingCurrentLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable location service to use current location'),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _hasLocationPermission = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final current = LatLng(position.latitude, position.longitude);
      setState(() {
        _selected = current;
        _hasLocationPermission = true;
      });
      await _resolveAddress(current);
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: current, zoom: 16),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location selected')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to fetch current location. Check GPS/location permission.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingCurrentLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final marker = Marker(
      markerId: const MarkerId('selected-location'),
      position: _selected,
      draggable: true,
      onDragEnd: _onSelected,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _selected, zoom: 14),
              markers: {marker},
              onTap: _onSelected,
              myLocationEnabled: _hasLocationPermission,
              myLocationButtonEnabled: false,
              onMapCreated: (controller) => _mapController = controller,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lat: ${_selected.latitude.toStringAsFixed(6)}'),
                Text('Lng: ${_selected.longitude.toStringAsFixed(6)}'),
                const SizedBox(height: 8),
                if (_loadingAddress)
                  const LinearProgressIndicator()
                else
                  Text(
                    _address.isEmpty ? 'Address not resolved yet' : _address,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadingCurrentLocation ? null : _useCurrentLocation,
                    icon: _loadingCurrentLocation
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Use Current Location'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        MapPickerResult(
                          latitude: _selected.latitude,
                          longitude: _selected.longitude,
                          address: _address,
                          city: _city,
                          state: _state,
                        ),
                      );
                    },
                    child: const Text('Use This Location'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
