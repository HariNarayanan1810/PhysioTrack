import 'package:flutter/material.dart';

import '../../models/doctor.dart';
import '../../models/patient.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

class AdminRemovedUsersPage extends StatefulWidget {
  const AdminRemovedUsersPage({super.key});

  @override
  State<AdminRemovedUsersPage> createState() => _AdminRemovedUsersPageState();
}

class _AdminRemovedUsersPageState extends State<AdminRemovedUsersPage> {
  late Future<List<Doctor>> _removedDoctorsFuture;
  late Future<List<Patient>> _removedPatientsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _removedDoctorsFuture = ApiService().getDoctors(removedOnly: true);
    _removedPatientsFuture = ApiService().getPatients(removedOnly: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Removed Users')),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_removedDoctorsFuture, _removedPatientsFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load removed users'));
          }
          final doctors = (snapshot.data?[0] as List<Doctor>? ?? []);
          final patients = (snapshot.data?[1] as List<Patient>? ?? []);
          if (doctors.isEmpty && patients.isEmpty) {
            return const Center(child: Text('No removed users'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (doctors.isNotEmpty) ...[
                Text('Removed Doctors', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...doctors.map((item) => Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          'City: ${item.city}\nQualification: ${item.qualification}\nRemoved: ${item.removedAt ?? 'N/A'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.adminDoctorProfileDetail,
                            arguments: {
                              'doctorId': item.id,
                              'removedView': true,
                            },
                          );
                        },
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              if (patients.isNotEmpty) ...[
                Text('Removed Patients', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...patients.map((item) => Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          'City: ${item.city ?? 'N/A'}\nAge: ${item.age}\nRemoved: ${item.removedAt ?? 'N/A'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.adminPatientProfileDetail,
                            arguments: {
                              'patientId': item.id,
                              'removedView': true,
                            },
                          );
                        },
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}
