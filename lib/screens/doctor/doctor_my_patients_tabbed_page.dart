import 'package:flutter/material.dart';

import '../../models/doctor_patient.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class DoctorMyPatientsTabbedPage extends StatefulWidget {
  const DoctorMyPatientsTabbedPage({super.key});

  @override
  State<DoctorMyPatientsTabbedPage> createState() =>
      _DoctorMyPatientsTabbedPageState();
}

class _DoctorMyPatientsTabbedPageState
    extends State<DoctorMyPatientsTabbedPage> {
  final ApiService _api = ApiService();
  int? _doctorId;
  late Future<List<DoctorPatientSummary>> _clinicFuture;
  late Future<List<DoctorPatientSummary>> _homeFuture;

  @override
  void initState() {
    super.initState();
    _clinicFuture = Future.value([]);
    _homeFuture = Future.value([]);
    _loadDoctor();
  }

  Future<void> _loadDoctor() async {
    final session = await SessionService().getSession();
    if (!mounted) return;
    final doctorId = session?.doctorId;
    setState(() {
      _doctorId = doctorId;
      if (doctorId == null) {
        _clinicFuture = Future.value([]);
        _homeFuture = Future.value([]);
      } else {
        _clinicFuture = _api.getDoctorPatients(
          doctorId: doctorId,
          appointmentType: 'clinic',
        );
        _homeFuture = _api.getDoctorPatients(
          doctorId: doctorId,
          appointmentType: 'home_visit',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Patients'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Clinic'),
              Tab(text: 'Home Visit'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PatientTab(future: _clinicFuture, doctorId: _doctorId, api: _api),
            _PatientTab(future: _homeFuture, doctorId: _doctorId, api: _api),
          ],
        ),
      ),
    );
  }
}

class _PatientTab extends StatelessWidget {
  const _PatientTab({
    required this.future,
    required this.doctorId,
    required this.api,
  });

  final Future<List<DoctorPatientSummary>> future;
  final int? doctorId;
  final ApiService api;

  String _visitLabel(String raw) {
    final v = raw.toUpperCase();
    if (v == 'CLINIC') return 'Clinic';
    if (v == 'HOME') return 'Home Visit';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DoctorPatientSummary>>(
      future: future,
      builder: (context, snapshot) {
        if (doctorId == null) {
          return const Center(child: Text('Doctor session missing'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load patients'));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No patients found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final imageUrl = api.resolveFileUrl(item.profileImage);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : null,
                  child: imageUrl.isEmpty
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                title: Text(item.name),
                subtitle: Text(
                  'Age: ${item.age}\n'
                  'Type: ${_visitLabel(item.appointmentType)}\n'
                  'Last: ${item.lastAppointmentDate}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.doctorPatientDetail,
                  arguments: {
                    'doctorId': doctorId,
                    'patientId': item.patientId,
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
