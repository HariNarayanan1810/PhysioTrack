import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/verification_request.dart';
import '../../services/api_service.dart';

class AdminDoctorVerificationDetailPage extends StatefulWidget {
  const AdminDoctorVerificationDetailPage({super.key});

  @override
  State<AdminDoctorVerificationDetailPage> createState() =>
      _AdminDoctorVerificationDetailPageState();
}

class _AdminDoctorVerificationDetailPageState
    extends State<AdminDoctorVerificationDetailPage> {
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

  Future<void> _approve(VerificationRequest request) async {
    setState(() => _busy = true);
    try {
      await _api.approveVerificationRequest(request.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Verification approved')));
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to approve')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(VerificationRequest request) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Verification'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Rejection reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonCtrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _api.rejectVerificationRequest(
        request.requestId,
        rejectionReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rejected: $reason')));
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to reject')));
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
    final arg = ModalRoute.of(context)?.settings.arguments;
    final requestId = arg is int ? arg : -1;

    if (requestId <= 0) {
      return const Scaffold(
        body: Center(child: Text('Invalid verification request')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Details')),
      body: FutureBuilder<VerificationRequest>(
        future: _api.getVerificationRequestById(requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Failed to load details'));
          }

          final request = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle(context, 'Professional Verification'),
              _kv('Full Name', request.fullName),
              _kv('Date of Birth', request.dateOfBirth),
              _kv('Qualification', request.qualification),
              _kv('University Name', request.universityName),
              _kv('Year of Graduation', '${request.yearOfGraduation}'),
              _kv('Years of Experience', '${request.yearsOfExperience}'),
              _kv('Specialization', request.specialization),
              _kv('License Number', request.licenseNumber),
              _kv('License Authority', request.licenseIssuingAuthority),
              _kv('License Expiry Date', request.licenseExpiryDate),
              _documentTile(
                'License Certificate',
                request.licenseCertificateUrl,
              ),
              _documentTile(
                'Degree Certificate',
                request.degreeCertificateUrl,
              ),
              _sectionTitle(context, 'Clinic / Practice'),
              _kv('Clinic Name', request.clinicName),
              _kv('Full Address', request.clinicAddress),
              _kv('City', request.city),
              _kv('Area', request.area),
              _kv('Pincode', request.pincode),
              _kv('Latitude', request.latitude.toString()),
              _kv('Longitude', request.longitude.toString()),
              _kv('Clinic Contact', request.clinicContactNumber),
              _kv(
                'Consultation Fee',
                request.consultationFee.toStringAsFixed(2),
              ),
              _kv(
                'Home Visit Available',
                request.homeVisitAvailable ? 'Yes' : 'No',
              ),
              _sectionTitle(context, 'Basic Account Details'),
              _kv('Email', request.doctorEmail ?? 'N/A'),
              _kv('Profile Image', request.doctorProfileImageUrl ?? 'N/A'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _reject(request),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _approve(request),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
