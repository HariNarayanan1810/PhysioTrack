import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../patient/patient_map_picker_page.dart';

class DoctorVerificationFormPage extends StatefulWidget {
  const DoctorVerificationFormPage({super.key});

  @override
  State<DoctorVerificationFormPage> createState() =>
      _DoctorVerificationFormPageState();
}

class _DoctorVerificationFormPageState
    extends State<DoctorVerificationFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _dob = TextEditingController();
  final _qualification = TextEditingController();
  final _universityName = TextEditingController();
  final _yearOfGraduation = TextEditingController();
  final _yearsOfExperience = TextEditingController();
  final _specialization = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _licenseAuthority = TextEditingController();
  final _licenseExpiryDate = TextEditingController();
  final _clinicName = TextEditingController();
  final _clinicAddress = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _pincode = TextEditingController();
  final _clinicContactNumber = TextEditingController();
  final _consultationFee = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  bool _homeVisitAvailable = false;
  bool _agreed = false;
  bool _isSubmitting = false;
  bool _isCheckingStatus = true;
  bool _isUploadingLicense = false;
  bool _isUploadingDegree = false;
  String _verificationStatus = 'not_applied';

  String? _licenseCertificateUrl;
  String? _degreeCertificateUrl;
  String? _licenseFileName;
  String? _degreeFileName;

  int? _doctorId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionService().getSession();
    if (!mounted) return;

    if (session == null) {
      setState(() {
        _doctorId = null;
        _isCheckingStatus = false;
      });
      return;
    }

    try {
      final doctor = await ApiService().getDoctorByUserId(session.userId);
      if (!mounted) return;
      setState(() {
        _doctorId = doctor?.id ?? session.doctorId;
        _verificationStatus = doctor?.verificationStatus ?? 'not_applied';
        _isCheckingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _doctorId = session.doctorId;
        _isCheckingStatus = false;
      });
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _dob.dispose();
    _qualification.dispose();
    _universityName.dispose();
    _yearOfGraduation.dispose();
    _yearsOfExperience.dispose();
    _specialization.dispose();
    _licenseNumber.dispose();
    _licenseAuthority.dispose();
    _licenseExpiryDate.dispose();
    _clinicName.dispose();
    _clinicAddress.dispose();
    _city.dispose();
    _area.dispose();
    _pincode.dispose();
    _clinicContactNumber.dispose();
    _consultationFee.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  String? _requiredField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _integerField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) return 'Numbers only';
    return null;
  }

  String? _decimalField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value.trim())) {
      return 'Invalid number';
    }
    return null;
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: DateTime.now(),
    );
    if (picked == null) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    ctrl.text = '${picked.year}-$month-$day';
  }

  Future<void> _pickLocation() async {
    final initialLat = double.tryParse(_latitude.text.trim());
    final initialLng = double.tryParse(_longitude.text.trim());

    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PatientMapPickerPage(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _latitude.text = result.latitude.toStringAsFixed(6);
      _longitude.text = result.longitude.toStringAsFixed(6);

      if (_city.text.trim().isEmpty && result.city.trim().isNotEmpty) {
        _city.text = result.city.trim();
      }
      if (_clinicAddress.text.trim().isEmpty && result.address.trim().isNotEmpty) {
        _clinicAddress.text = result.address.trim();
      }
    });
  }

  Future<void> _pickAndUploadDocument({required bool isLicense}) async {
    final fileResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
    );

    if (fileResult == null || fileResult.files.isEmpty) return;
    final file = fileResult.files.first;
    final bytes = file.bytes;

    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read selected file')),
      );
      return;
    }

    setState(() {
      if (isLicense) {
        _isUploadingLicense = true;
      } else {
        _isUploadingDegree = true;
      }
    });

    try {
      final fileUrl = await ApiService().uploadVerificationDocumentBytes(
        bytes: bytes,
        fileName: file.name,
      );

      if (!mounted) return;
      setState(() {
        if (isLicense) {
          _licenseCertificateUrl = fileUrl;
          _licenseFileName = file.name;
        } else {
          _degreeCertificateUrl = fileUrl;
          _degreeFileName = file.name;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isLicense ? 'License' : 'Degree'} file uploaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (isLicense) {
            _isUploadingLicense = false;
          } else {
            _isUploadingDegree = false;
          }
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_verificationStatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your verification request is under review')),
      );
      return;
    }
    if (_verificationStatus == 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already a verified physiotherapist'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept declaration')),
      );
      return;
    }

    if (_doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor session missing. Please login again.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().createVerificationRequest(
        doctorId: _doctorId!,
        fullName: _fullName.text.trim(),
        dateOfBirth: _dob.text.trim(),
        qualification: _qualification.text.trim(),
        universityName: _universityName.text.trim(),
        yearOfGraduation: int.parse(_yearOfGraduation.text.trim()),
        yearsOfExperience: int.parse(_yearsOfExperience.text.trim()),
        specialization: _specialization.text.trim(),
        licenseNumber: _licenseNumber.text.trim(),
        licenseIssuingAuthority: _licenseAuthority.text.trim(),
        licenseExpiryDate: _licenseExpiryDate.text.trim(),
        clinicName: _clinicName.text.trim(),
        clinicAddress: _clinicAddress.text.trim(),
        city: _city.text.trim(),
        area: _area.text.trim(),
        pincode: _pincode.text.trim(),
        clinicContactNumber: _clinicContactNumber.text.trim(),
        consultationFee: double.parse(_consultationFee.text.trim()),
        homeVisitAvailable: _homeVisitAvailable,
        latitude: double.parse(_latitude.text.trim()),
        longitude: double.parse(_longitude.text.trim()),
        licenseCertificateUrl: _licenseCertificateUrl,
        degreeCertificateUrl: _degreeCertificateUrl,
      );
      if (!mounted) return;
      setState(() => _verificationStatus = 'pending');
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submitted'),
          content: const Text(
            'Application submitted successfully. Await admin approval.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _dateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      validator: _requiredField,
    );
  }

  Widget _documentUploadTile({
    required String title,
    required bool isUploading,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: isUploading ? null : onTap,
                icon: const Icon(Icons.upload_file),
                label: Text(isUploading ? 'Uploading...' : 'Upload File'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName ?? 'No file selected',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Accepted: PDF, DOC, DOCX',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Verification')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_verificationStatus == 'pending' || _verificationStatus == 'approved') {
      final message = _verificationStatus == 'approved'
          ? 'You are already a verified physiotherapist'
          : 'Your verification request is under review';
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Verification')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _verificationStatus == 'approved'
                      ? Icons.verified
                      : Icons.hourglass_top_outlined,
                  size: 54,
                  color: const Color(0xFF1B5E7A),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Verification')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            _dateField(controller: _dob, label: 'Date of Birth'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qualification,
              decoration: const InputDecoration(labelText: 'Qualification'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _universityName,
              decoration: const InputDecoration(labelText: 'University Name'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearOfGraduation,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Year of Graduation'),
              validator: _integerField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearsOfExperience,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Years of Experience'),
              validator: _integerField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specialization,
              decoration: const InputDecoration(labelText: 'Specialization'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _licenseNumber,
              decoration: const InputDecoration(labelText: 'License Number'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _licenseAuthority,
              decoration: const InputDecoration(
                labelText: 'License Issuing Authority',
              ),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            _dateField(
              controller: _licenseExpiryDate,
              label: 'License Expiry Date',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clinicName,
              decoration: const InputDecoration(labelText: 'Clinic Name'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clinicAddress,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Clinic Address'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'City'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _area,
              decoration: const InputDecoration(labelText: 'Area'),
              validator: _requiredField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pincode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pincode'),
              validator: _integerField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clinicContactNumber,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Clinic Contact Number'),
              validator: _integerField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _consultationFee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Consultation Fee'),
              validator: _decimalField,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _homeVisitAvailable,
              onChanged: (value) => setState(() => _homeVisitAvailable = value),
              title: const Text('Home Visit Available'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Clinic Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Pick on Map'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _latitude,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Latitude'),
              validator: _decimalField,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _longitude,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Longitude'),
              validator: _decimalField,
            ),
            const SizedBox(height: 12),
            _documentUploadTile(
              title: 'License Certificate (Optional)',
              isUploading: _isUploadingLicense,
              fileName: _licenseFileName,
              onTap: () => _pickAndUploadDocument(isLicense: true),
            ),
            const SizedBox(height: 12),
            _documentUploadTile(
              title: 'Degree Certificate (Optional)',
              isUploading: _isUploadingDegree,
              fileName: _degreeFileName,
              onTap: () => _pickAndUploadDocument(isLicense: false),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _agreed,
              onChanged: (value) => setState(() => _agreed = value ?? false),
              title: const Text('I confirm the above details are valid'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }
}
