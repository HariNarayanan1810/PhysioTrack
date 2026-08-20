import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/fcm_service.dart';
import '../../services/session_service.dart';

class RootGatePage extends StatefulWidget {
  const RootGatePage({super.key});

  @override
  State<RootGatePage> createState() => _RootGatePageState();
}

class _RootGatePageState extends State<RootGatePage> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await SessionService().getSession();
    if (!mounted || session == null) return;
    await FcmService.instance.syncTokenWithBackend();

    final role = session.role.toUpperCase();
    if (role == 'ADMIN') {
      Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
    } else if (role == 'DOCTOR') {
      Navigator.pushReplacementNamed(context, AppRoutes.doctorDashboard);
    } else if (role == 'PATIENT') {
      Navigator.pushReplacementNamed(context, AppRoutes.patientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PhysioTrack')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose your role',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: 'Admin',
              icon: Icons.admin_panel_settings_outlined,
              onTap: () => Navigator.pushNamed(context, AppRoutes.adminLogin),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              title: 'Doctor',
              icon: Icons.medical_services_outlined,
              onTap: () => Navigator.pushNamed(context, AppRoutes.doctorLogin),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              title: 'Patient',
              icon: Icons.accessibility_new_outlined,
              onTap: () => Navigator.pushNamed(context, AppRoutes.patientLogin),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
