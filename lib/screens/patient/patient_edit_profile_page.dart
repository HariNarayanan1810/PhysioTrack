import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/patient.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'patient_map_picker_page.dart';

class PatientEditProfilePage extends StatefulWidget {
  const PatientEditProfilePage({super.key});

  @override
  State<PatientEditProfilePage> createState() => _PatientEditProfilePageState();
}

class _PatientEditProfilePageState extends State<PatientEditProfilePage> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final List<String> _states = const [
    'Tamil Nadu',
    'Kerala',
    'Karnataka',
    'Andhra Pradesh',
    'Telangana',
    'Maharashtra',
  ];

  String? _selectedState;
  bool _loading = true;
  bool _saving = false;
  bool _profileExists = false;

  double? _latitude;
  double? _longitude;
  String _profileImagePath = '';
  Uint8List? _pickedImageBytes;
  String _pickedImageName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _ageCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final session = await SessionService().getSession();
      if (session != null) {
        _nameCtrl.text = session.name;
        _emailCtrl.text = session.email;
      }

      final Patient? profile = await _api.getPatientProfile();
      if (profile != null) {
        _profileExists = true;
        _nameCtrl.text = profile.name;
        _emailCtrl.text = profile.email;
        _phoneCtrl.text = profile.phone == 'NA' ? '' : profile.phone;
        _dobCtrl.text = _normalizeDate(profile.dob);
        _ageCtrl.text = profile.age > 0 ? '${profile.age}' : '';
        _selectedState = _emptyToNull(profile.state);
        _cityCtrl.text = profile.city ?? '';
        _addressCtrl.text = profile.address == 'NA' ? '' : profile.address;
        _latitude = profile.latitude;
        _longitude = profile.longitude;
        _profileImagePath = profile.profileImage ?? '';
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _emptyToNull(String? value) {
    final data = (value ?? '').trim();
    if (data.isEmpty || data == 'NA') return null;
    return data;
  }

  String _normalizeDate(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return '';
    try {
      final date = DateTime.parse(raw);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return raw.split('T').first;
    }
  }

  Future<void> _pickDob() async {
    final initial = _dobCtrl.text.isNotEmpty
        ? DateTime.tryParse(_dobCtrl.text) ?? DateTime(2000, 1, 1)
        : DateTime(2000, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;
    _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    _ageCtrl.text = '${_calculateAge(picked)}';
    setState(() {});
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    final hasBirthdayPassed =
        now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
    if (!hasBirthdayPassed) age--;
    return age < 0 ? 0 : age;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageName = file.name;
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PatientMapPickerPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      if (result.address.trim().isNotEmpty) {
        _addressCtrl.text = result.address.trim();
      }
      if (result.city.trim().isNotEmpty) {
        _cityCtrl.text = result.city.trim();
      }
      if (result.state.trim().isNotEmpty && _states.contains(result.state.trim())) {
        _selectedState = result.state.trim();
      }
    });
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick location on map')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      var imagePath = _profileImagePath;
      if (_pickedImageBytes != null) {
        imagePath = await _api.uploadPatientProfileImageBytes(
          bytes: _pickedImageBytes!,
          fileName: _pickedImageName.isEmpty ? 'patient.jpg' : _pickedImageName,
        );
      }

      if (_profileExists) {
        await _api.updatePatientProfile(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? 'NA' : _phoneCtrl.text.trim(),
          dob: _dobCtrl.text.trim(),
          state: _selectedState ?? '',
          city: _cityCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          profileImage: imagePath,
        );
      } else {
        await _api.createPatientProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? 'NA' : _phoneCtrl.text.trim(),
          dob: _dobCtrl.text.trim(),
          state: _selectedState ?? '',
          city: _cityCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          profileImage: imagePath,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _api.resolveFileUrl(_profileImagePath);
    final ImageProvider? imageProvider = _pickedImageBytes != null
        ? MemoryImage(_pickedImageBytes!)
        : (imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundImage: imageProvider,
                          child: imageProvider == null
                              ? const Icon(Icons.person_outline, size: 32)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Change Image'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dobCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'DOB',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: _pickDob,
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'DOB is required';
                      final parsed = DateTime.tryParse(value);
                      if (parsed == null) return 'DOB is invalid';
                      if (parsed.isAfter(DateTime.now())) return 'DOB cannot be future';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Age'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedState,
                    items: _states
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedState = value),
                    decoration: const InputDecoration(labelText: 'State'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'State is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'City is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Full Address'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Pick Location on Map'),
                  ),
                  const SizedBox(height: 8),
                  if (_latitude != null && _longitude != null) ...[
                    Text(
                      'Lat: ${_latitude!.toStringAsFixed(6)} | Lng: ${_longitude!.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_latitude!, _longitude!),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('profile-location'),
                              position: LatLng(_latitude!, _longitude!),
                            ),
                          },
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          scrollGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Profile'),
                  ),
                ],
              ),
            ),
    );
  }
}
