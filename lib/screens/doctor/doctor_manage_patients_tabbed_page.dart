import 'package:flutter/material.dart';

import '../../models/patient.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class DoctorManagePatientsTabbedPage extends StatefulWidget {
  const DoctorManagePatientsTabbedPage({super.key});

  @override
  State<DoctorManagePatientsTabbedPage> createState() =>
      _DoctorManagePatientsTabbedPageState();
}

class _DoctorManagePatientsTabbedPageState
    extends State<DoctorManagePatientsTabbedPage> {
  final ApiService _api = ApiService();

  Future<List<Patient>> _loadPatients() async {
    final session = await SessionService().getSession();
    final doctorId = session?.doctorId;
    if (doctorId == null) return [];
    return _api.getPatients(doctorId: doctorId);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Patients'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Home Visit'),
              Tab(text: 'Clinic'),
            ],
          ),
        ),
        body: FutureBuilder<List<Patient>>(
          future: _loadPatients(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load patients'));
            }
            final all = snapshot.data ?? [];
            final homeVisit = <_PatientBrief>[];
            final clinic = <_PatientBrief>[];
            for (var i = 0; i < all.length; i++) {
              final p = all[i];
              final item = _PatientBrief(p.name, p.address, p.age);
              if (i.isEven) {
                homeVisit.add(item);
              } else {
                clinic.add(item);
              }
            }
            return TabBarView(
              children: [
                _PatientList(items: homeVisit),
                _PatientList(items: clinic),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PatientList extends StatelessWidget {
  const _PatientList({required this.items});

  final List<_PatientBrief> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No patients found'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(item.name),
            subtitle: Text(item.location),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.doctorPatientDetail,
              arguments: {
                'name': item.name,
                'age': item.age,
                'location': item.location,
              },
            ),
          ),
        );
      },
    );
  }
}

class _PatientBrief {
  const _PatientBrief(this.name, this.location, this.age);

  final String name;
  final String location;
  final int age;
}
