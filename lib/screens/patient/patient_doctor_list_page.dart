import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/doctor.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import 'patient_doctor_detail_page.dart';

class PatientDoctorListPage extends StatefulWidget {
  const PatientDoctorListPage({super.key});

  @override
  State<PatientDoctorListPage> createState() => _PatientDoctorListPageState();
}

class _PatientDoctorListPageState extends State<PatientDoctorListPage> {
  final ApiService _api = ApiService();
  late Future<List<Doctor>> _approvedDoctorsFuture;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _approvedDoctorsFuture = _api.getApprovedDoctors();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() {
        _approvedDoctorsFuture = _api.getApprovedDoctors();
      });
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _approvedDoctorsFuture = _api.getApprovedDoctors();
    });
    await _approvedDoctorsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approved Doctors')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Doctor>>(
          future: _approvedDoctorsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load doctors'));
            }
            final doctors = snapshot.data ?? [];
            if (doctors.isEmpty) {
              return const Center(child: Text('No approved doctors available'));
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: doctors.length,
              itemBuilder: (context, index) {
                final d = doctors[index];
                return Card(
                  key: ValueKey(d.id),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: d.profileImageUrl.isNotEmpty
                          ? NetworkImage(d.profileImageUrl)
                          : null,
                      child: d.profileImageUrl.isEmpty
                          ? const Icon(Icons.medical_services_outlined)
                          : null,
                    ),
                    title: Text(d.name),
                    subtitle: Text('${d.clinicName} - ${d.qualification}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(d.rating.toStringAsFixed(1)),
                      ],
                    ),
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.patientDoctorDetail,
                      arguments: DoctorArgs(
                        id: d.id,
                        name: d.name,
                        clinic: d.clinicName,
                        rating: d.rating,
                        age: d.age,
                        experience: d.yearsOfExperience,
                        address: 'Clinic: ${d.clinicName}',
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
