import 'package:flutter/material.dart';

import '../../models/doctor.dart';
import '../../models/patient.dart';
import '../../models/verification_request.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ApiService _api = ApiService();
  bool _loadingStats = true;
  int _pendingCount = 0;
  int _doctorCount = 0;
  int _patientCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        _api.getVerificationRequests(status: 'PENDING'),
        _api.getDoctors(verifiedOnly: true),
        _api.getPatients(),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingCount = (results[0] as List).length;
        _doctorCount = (results[1] as List).length;
        _patientCount = (results[2] as List).length;
        _loadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1B5E7A)),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Admin Menu',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('Removed Users'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminRemovedUsers);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('All Payments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminPayments);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('User Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminReports);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await AuthService().logout();
                if (!context.mounted) return;
                Navigator.popUntil(context, (r) => r.isFirst);
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _ProfileHeader(
              name: 'Admin User',
              subtitle: 'System Administrator',
              icon: Icons.admin_panel_settings_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Pending Approvals',
                    value: _loadingStats ? '...' : '$_pendingCount',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Total Active Doctors',
                    value: _loadingStats ? '...' : '$_doctorCount',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Total Patients',
                    value: _loadingStats ? '...' : '$_patientCount',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Pending'),
                        Tab(text: 'Active Doctors'),
                        Tab(text: 'Patients'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _PendingVerificationTab(onChanged: _loadStats),
                          const _ActiveDoctorsTab(),
                          const _PatientsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingVerificationTab extends StatefulWidget {
  const _PendingVerificationTab({this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<_PendingVerificationTab> createState() =>
      _PendingVerificationTabState();
}

class _PendingVerificationTabState extends State<_PendingVerificationTab> {
  final ApiService _api = ApiService();
  late Future<List<VerificationRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getVerificationRequests(status: 'PENDING');
  }

  void _reload() {
    setState(() {
      _future = _api.getVerificationRequests(status: 'PENDING');
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VerificationRequest>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Failed to load verification requests'),
          );
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(child: Text('No pending verification requests'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = requests[index];
            return Card(
              child: ListTile(
                title: Text(item.fullName),
                subtitle: Text(
                  'City: ${item.city}\nQualification: ${item.qualification}\nSubmitted: ${item.submittedAt}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final updated = await Navigator.pushNamed(
                    context,
                    AppRoutes.adminVerificationDetail,
                    arguments: item.requestId,
                  );
                  if (updated == true) {
                    _reload();
                    widget.onChanged?.call();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ActiveDoctorsTab extends StatefulWidget {
  const _ActiveDoctorsTab();

  @override
  State<_ActiveDoctorsTab> createState() => _ActiveDoctorsTabState();
}

class _ActiveDoctorsTabState extends State<_ActiveDoctorsTab> {
  late Future<List<Doctor>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getDoctors(verifiedOnly: true);
  }

  void _reload() {
    setState(() {
      _future = ApiService().getDoctors(verifiedOnly: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Doctor>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load doctors'));
        }
        final doctors = snapshot.data ?? [];
        if (doctors.isEmpty) {
          return const Center(child: Text('No Active Doctors'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: doctors.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = doctors[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.medical_services_outlined),
                ),
                title: Text(item.name),
                subtitle: const Text('Status: Active'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final updated = await Navigator.pushNamed(
                    context,
                    AppRoutes.adminDoctorProfileDetail,
                    arguments: {'doctorId': item.id, 'removedView': false},
                  );
                  if (updated == true && mounted) {
                    _reload();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _PatientsTab extends StatefulWidget {
  const _PatientsTab();

  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  late Future<List<Patient>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getPatients();
  }

  void _reload() {
    setState(() {
      _future = ApiService().getPatients();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Patient>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load patients'));
        }
        final patients = snapshot.data ?? [];
        if (patients.isEmpty) {
          return const Center(child: Text('No Active Patients'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: patients.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = patients[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(item.name),
                subtitle: const Text('Status: Active'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final updated = await Navigator.pushNamed(
                    context,
                    AppRoutes.adminPatientProfileDetail,
                    arguments: {
                      'patientId': item.id,
                      'removedView': false,
                    },
                  );
                  if (updated == true && mounted) {
                    _reload();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  final String name;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 26, child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
