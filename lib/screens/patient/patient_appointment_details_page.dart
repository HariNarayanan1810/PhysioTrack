import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

class PatientAppointmentDetailsPage extends StatefulWidget {
  const PatientAppointmentDetailsPage({super.key});

  @override
  State<PatientAppointmentDetailsPage> createState() =>
      _PatientAppointmentDetailsPageState();
}

class _PatientAppointmentDetailsPageState
    extends State<PatientAppointmentDetailsPage> {
  final ApiService _api = ApiService();
  Appointment? _appointment;
  bool _cancelling = false;

  String _formatStatus(String status) {
    final normalized = status.trim().toUpperCase();
    if (normalized.isEmpty) return 'Unknown';
    return normalized[0] + normalized.substring(1).toLowerCase();
  }

  String _formatVisitType(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'HOME') return 'Home Visit';
    if (normalized == 'CLINIC') return 'Clinic Visit';
    return value;
  }

  Appointment _copyWithStatus(Appointment source, String status) {
    return Appointment(
      id: source.id,
      doctorId: source.doctorId,
      patientId: source.patientId,
      doctorName: source.doctorName,
      patientName: source.patientName,
      appointmentDate: source.appointmentDate,
      appointmentTime: source.appointmentTime,
      status: status,
      visitType: source.visitType,
      preferredPaymentMethod: source.preferredPaymentMethod,
      distanceKm: source.distanceKm,
      sessionFee: source.sessionFee,
      isSpecialSession: source.isSpecialSession,
      specialFeeAmount: source.specialFeeAmount,
      specialFeeReason: source.specialFeeReason,
      actualStartTime: source.actualStartTime,
      actualEndTime: source.actualEndTime,
      liveTrackingEnabled: source.liveTrackingEnabled,
      doctorLiveLatitude: source.doctorLiveLatitude,
      doctorLiveLongitude: source.doctorLiveLongitude,
      currentEtaMinutes: source.currentEtaMinutes,
      lastLocationUpdatedAt: source.lastLocationUpdatedAt,
    );
  }

  Future<void> _cancelAppointment() async {
    final appointment = _appointment;
    if (appointment == null || _cancelling) return;

    setState(() => _cancelling = true);
    try {
      await _api.cancelAppointment(appointmentId: appointment.id);
      if (!mounted) return;
      setState(() {
        _appointment = _copyWithStatus(appointment, 'CANCELLED');
        _cancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appointment != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Appointment) {
      _appointment = args;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _appointment;

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Appointment Details')),
        body: const Center(child: Text('Appointment details not available')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Appointment Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text('Date: ${appointment.appointmentDate}'),
                    const SizedBox(height: 6),
                    Text('Time: ${appointment.appointmentTime}'),
                    const SizedBox(height: 6),
                    Text('Visit Type: ${_formatVisitType(appointment.visitType)}'),
                    const SizedBox(height: 6),
                    Text('Status: ${_formatStatus(appointment.status)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (appointment.status.toUpperCase() == 'COMPLETED')
              FilledButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.patientPayments);
                },
                child: const Text('Pay Now'),
              )
            else if (appointment.status.toUpperCase() == 'REJECTED')
              const FilledButton(
                onPressed: null,
                child: Text('Appointment Rejected'),
              )
            else if (appointment.status.toUpperCase() == 'CANCELLED')
              const FilledButton(
                onPressed: null,
                child: Text('Appointment Cancelled'),
              )
            else
              FilledButton(
                onPressed: _cancelling ? null : _cancelAppointment,
                child: Text(
                  _cancelling ? 'Cancelling...' : 'Cancel Appointment',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
