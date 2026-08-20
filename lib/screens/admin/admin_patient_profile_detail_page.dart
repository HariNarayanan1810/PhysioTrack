import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

class AdminPatientProfileDetailPage extends StatefulWidget {
  const AdminPatientProfileDetailPage({super.key});

  @override
  State<AdminPatientProfileDetailPage> createState() =>
      _AdminPatientProfileDetailPageState();
}

class _AdminPatientProfileDetailPageState
    extends State<AdminPatientProfileDetailPage> {
  final ApiService _api = ApiService();
  bool _busy = false;

  Future<void> _removePatient(Patient patient) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Patient'),
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
      await _api.removePatient(
        patient.id,
        removedReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient removed successfully')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove patient')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label)),
          const Text(': '),
          Expanded(child: Text(value.isEmpty ? 'N/A' : value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final data = args is Map<String, dynamic> ? args : <String, dynamic>{};
    final patientId = data['patientId'] as int? ?? -1;
    final removedView = data['removedView'] as bool? ?? false;

    if (patientId <= 0) {
      return const Scaffold(
        body: Center(child: Text('Invalid patient profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Profile')),
      body: FutureBuilder<Patient>(
        future: _api.getPatientById(patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Failed to load patient profile'));
          }
          final patient = snapshot.data!;
          final imageUrl = _api.resolveFileUrl(patient.profileImage);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                  child: imageUrl.isEmpty
                      ? const Icon(Icons.person_outline, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              _kv('Name', patient.name),
              _kv('Email', patient.email),
              _kv('Age', '${patient.age}'),
              _kv('DOB', patient.dob ?? ''),
              _kv('Phone', patient.phone),
              _kv('State', patient.state ?? ''),
              _kv('City', patient.city ?? ''),
              _kv('Address', patient.address),
              _kv('Latitude', patient.latitude?.toString() ?? ''),
              _kv('Longitude', patient.longitude?.toString() ?? ''),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.adminReports,
                  arguments: {
                    'targetRole': 'PATIENT',
                    'targetPatientId': patient.id,
                  },
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('View Reports About This Patient'),
              ),
              if (removedView) ...[
                const SizedBox(height: 8),
                _kv('Removed Reason', patient.removedReason ?? ''),
                _kv('Removed At', patient.removedAt ?? ''),
              ],
              const SizedBox(height: 20),
              if (!removedView)
                FilledButton(
                  onPressed: _busy ? null : () => _removePatient(patient),
                  child: const Text('Remove Patient'),
                ),
            ],
          );
        },
      ),
    );
  }
}
