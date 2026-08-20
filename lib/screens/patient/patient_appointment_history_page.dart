import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class PatientAppointmentHistoryPage extends StatefulWidget {
  const PatientAppointmentHistoryPage({super.key});

  @override
  State<PatientAppointmentHistoryPage> createState() =>
      _PatientAppointmentHistoryPageState();
}

class _PatientAppointmentHistoryPageState
    extends State<PatientAppointmentHistoryPage> {
  final ApiService _api = ApiService();
  List<Appointment> _appointments = const [];
  bool _loading = true;
  String? _error;

  Future<void> _loadAppointments() async {
    final session = await SessionService().getSession();
    final patientId = session?.patientId;
    if (patientId == null) {
      setState(() {
        _appointments = const [];
        _loading = false;
      });
      return;
    }
    try {
      final data = await _api.getAppointments(patientId: patientId);
      if (!mounted) return;
      setState(() {
        _appointments = data;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appointments = const [];
        _loading = false;
        _error = 'Failed to load appointments';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _appointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final appt = _appointments[index];
                    return Card(
                      child: ListTile(
                        title: Text('${appt.doctorName} - ${appt.appointmentDate}'),
                        subtitle: Text('Status: ${appt.status}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final changed = await Navigator.pushNamed(
                            context,
                            AppRoutes.patientAppointmentDetails,
                            arguments: appt,
                          );
                          if (changed == true && mounted) {
                            setState(() => _loading = true);
                            await _loadAppointments();
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
