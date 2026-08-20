import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/verification_request.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

class AdminDoctorProfileDetailPage extends StatefulWidget {
  const AdminDoctorProfileDetailPage({super.key});

  @override
  State<AdminDoctorProfileDetailPage> createState() =>
      _AdminDoctorProfileDetailPageState();
}

class _AdminDoctorProfileDetailPageState
    extends State<AdminDoctorProfileDetailPage> {
  final ApiService _api = ApiService();
  bool _busy = false;

  Future<void> _openDocument(String path) async {
    final resolved = _api.resolveFileUrl(path);
    if (resolved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document not available')),
      );
      return;
    }

    final uri = Uri.tryParse(resolved);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid document URL')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open document')),
      );
    }
  }

  Future<void> _removeDoctor(VerificationRequest profile) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Doctor'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Removal reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _api.removeDoctor(
        profile.doctorId,
        removedReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor removed successfully')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove doctor')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 170, child: Text(label)),
          const Text(': '),
          Expanded(child: Text(value.isEmpty ? 'N/A' : value)),
        ],
      ),
    );
  }

  Widget _documentTile(String label, String? path) {
    final value = (path ?? '').trim();
    final fileName = value.isEmpty ? 'N/A' : value.split('/').last;
    final lowerName = fileName.toLowerCase();
    final icon = lowerName.endsWith('.pdf')
        ? Icons.picture_as_pdf_outlined
        : Icons.description_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 170, child: Text(label)),
          const Text(': '),
          Expanded(
            child: value.isEmpty
                ? const Text('N/A')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openDocument(value),
                            icon: Icon(icon),
                            label: const Text('Open Document'),
                          ),
                          SelectableText(
                            _api.resolveFileUrl(value),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final data = args is Map<String, dynamic> ? args : <String, dynamic>{};
    final doctorId = data['doctorId'] as int? ?? -1;
    final removedView = data['removedView'] as bool? ?? false;

    if (doctorId <= 0) {
      return const Scaffold(
        body: Center(child: Text('Invalid doctor profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Profile')),
      body: FutureBuilder<VerificationRequest>(
        future: _api.getDoctorProfile(doctorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Failed to load doctor profile'));
          }
          final profile = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle(context, 'Section A: Professional Verification'),
              _kv('Full Name', profile.fullName),
              _kv('Date of Birth', profile.dateOfBirth),
              _kv('Qualification', profile.qualification),
              _kv('University Name', profile.universityName),
              _kv('Year of Graduation', '${profile.yearOfGraduation}'),
              _kv('Years of Experience', '${profile.yearsOfExperience}'),
              _kv('Specialization', profile.specialization),
              _kv('License Number', profile.licenseNumber),
              _kv('License Authority', profile.licenseIssuingAuthority),
              _kv('License Expiry Date', profile.licenseExpiryDate),
              _documentTile(
                'License Certificate',
                profile.licenseCertificateUrl,
              ),
              _documentTile(
                'Degree Certificate',
                profile.degreeCertificateUrl,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminReports,
                  arguments: {
                    'targetRole': 'DOCTOR',
                    'targetDoctorId': profile.doctorId,
                  },
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('View Reports About This Doctor'),
              ),
              _sectionTitle(context, 'Section B: Clinic / Practice'),
              _kv('Clinic Name', profile.clinicName),
              _kv('Full Address', profile.clinicAddress),
              _kv('City', profile.city),
              _kv('Area', profile.area),
              _kv('Pincode', profile.pincode),
              _kv('Latitude', profile.latitude.toString()),
              _kv('Longitude', profile.longitude.toString()),
              _kv('Clinic Contact', profile.clinicContactNumber),
              _kv('Consultation Fee', profile.consultationFee.toStringAsFixed(2)),
              _kv('Home Visit Available', profile.homeVisitAvailable ? 'Yes' : 'No'),
              _sectionTitle(context, 'Section C: Basic Account Details'),
              _kv('Email', profile.doctorEmail ?? 'N/A'),
              _kv('Profile Image', profile.doctorProfileImageUrl ?? 'N/A'),
              if (removedView) ...[
                _sectionTitle(context, 'Removal Details'),
                _kv('Removed Reason', profile.removedReason ?? 'N/A'),
                _kv('Removed At', profile.removedAt ?? 'N/A'),
              ],
              const SizedBox(height: 20),
              if (!removedView)
                FilledButton(
                  onPressed: _busy ? null : () => _removeDoctor(profile),
                  child: const Text('Remove Doctor'),
                ),
            ],
          );
        },
      ),
    );
  }
}
