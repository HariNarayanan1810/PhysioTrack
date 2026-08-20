import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/doctor.dart';
import '../../models/patient.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import 'patient_doctor_detail_page.dart';

class PatientAppointmentFormPage extends StatefulWidget {
  const PatientAppointmentFormPage({super.key});

  @override
  State<PatientAppointmentFormPage> createState() =>
      _PatientAppointmentFormPageState();
}

class _PatientAppointmentFormPageState
    extends State<PatientAppointmentFormPage> {
  final ApiService _api = ApiService();
  final _nameCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _visitType = 'Clinic Visit';
  String _paymentMethod = 'cash';
  int? _patientId;
  Doctor? _doctorProfile;
  Patient? _patientProfile;
  bool _doctorLoaded = false;
  bool _pricingLoading = false;
  double? _distanceKm;
  double _baseFee = 0;
  double _distanceCharge = 0;
  double _sessionFee = 0;
  String? _pricingNote;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_doctorLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DoctorArgs && args.id > 0) {
      _doctorLoaded = true;
      _loadDoctorProfile(args.id);
    }
  }

  Future<void> _loadSession() async {
    final session = await SessionService().getSession();
    if (!mounted || session == null) return;
    Patient? profile;
    try {
      profile = await _api.getPatientProfile();
    } catch (_) {
      profile = null;
    }
    setState(() {
      _patientId = session.patientId;
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = session.name;
      }
      _patientProfile = profile;
    });
    _recalculateFeePreview();
  }

  Future<void> _loadDoctorProfile(int doctorId) async {
    setState(() => _pricingLoading = true);
    try {
      final doctor = await _api.getDoctorById(doctorId);
      if (!mounted) return;
      setState(() {
        _doctorProfile = doctor;
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() => _pricingLoading = false);
      }
      _recalculateFeePreview();
    }
  }

  void _recalculateFeePreview() {
    final doctor = _doctorProfile;
    if (doctor == null || !mounted) return;

    double baseFee = _visitType == 'Home Visit'
        ? doctor.homeVisitBaseFee
        : doctor.clinicFee;
    double distanceCharge = 0;
    double? distanceKm;
    String? pricingNote;

    if (_visitType == 'Home Visit') {
      final patient = _patientProfile;
      if (doctor.perKmCharge != null &&
          patient?.latitude != null &&
          patient?.longitude != null &&
          doctor.latitude != 0 &&
          doctor.longitude != 0) {
        final distanceMeters = Geolocator.distanceBetween(
          doctor.latitude,
          doctor.longitude,
          patient!.latitude!,
          patient.longitude!,
        );
        distanceKm = distanceMeters / 1000;
        distanceCharge = distanceKm * doctor.perKmCharge!;
      } else if (doctor.perKmCharge != null) {
        pricingNote =
            'Distance charge is optional and will be added when location data is available.';
      } else {
        pricingNote = 'Home visit uses the fixed base fee for this doctor.';
      }
    }

    setState(() {
      _distanceKm = distanceKm;
      _baseFee = _roundMoney(baseFee);
      _distanceCharge = _roundMoney(distanceCharge);
      _sessionFee = _roundMoney(baseFee + distanceCharge);
      _pricingNote = pricingNote;
    });
  }

  double _roundMoney(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(now.year + 1),
      initialDate: _selectedDate ?? today,
    );
    if (picked == null) return;
    if (picked.isBefore(today)) {
      _showError('Past dates are not allowed');
      return;
    }

    setState(() {
      _selectedDate = picked;
      if (_selectedTime != null &&
          _isToday(picked) &&
          _isPastTime(_selectedTime!)) {
        _selectedTime = null;
      }
    });
  }

  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      _showError('Please select an appointment date first');
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    if (_isToday(_selectedDate!) && _isPastTime(picked)) {
      _showError('Please select a future time for today');
      return;
    }
    setState(() => _selectedTime = picked);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isPastTime(TimeOfDay time) {
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return !selectedDateTime.isAfter(now);
  }

  Future<void> _submit(DoctorArgs doctor) async {
    final name = _nameCtrl.text.trim();
    if (name.length < 3) {
      _showError('Patient name must be at least 3 characters');
      return;
    }
    if (_selectedDate == null) {
      _showError('Please select an appointment date');
      return;
    }
    if (_selectedTime == null) {
      _showError('Please select an appointment time');
      return;
    }
    if (_isToday(_selectedDate!) && _isPastTime(_selectedTime!)) {
      _showError('For today, please select a future time');
      return;
    }
    if (doctor.id <= 0) {
      _showError('Doctor details missing. Please choose a doctor again');
      return;
    }
    if (_patientId == null) {
      _showError('User session not found. Please login again');
      return;
    }

    final dateStr =
        '${_selectedDate!.day.toString().padLeft(2, '0')}-'
        '${_selectedDate!.month.toString().padLeft(2, '0')}-'
        '${_selectedDate!.year}';
    final timeStr = _selectedTime!.format(context);

    Map<String, dynamic> result;
    try {
      result = await _api.createAppointment(
        doctorId: doctor.id,
        patientId: _patientId!,
        date: dateStr,
        time: timeStr,
        visitType: _visitType == 'Home Visit' ? 'HOME' : 'CLINIC',
        paymentMethod: _paymentMethod,
      );
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
      return;
    }

    final bookedFee =
        ((result['session_fee'] as num?)?.toDouble()) ?? _sessionFee;
    final bookedDistance = (result['distance_km'] as num?)?.toDouble();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(
          _visitType == 'Home Visit' && bookedDistance != null
              ? 'Appointment request sent successfully.\n\nEstimated fee: Rs ${bookedFee.toStringAsFixed(2)}\nDistance: ${bookedDistance.toStringAsFixed(2)} km'
              : 'Appointment request sent successfully.\n\nEstimated fee: Rs ${bookedFee.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.patientDashboard,
                (route) => route.isFirst,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFeeBreakdownCard() {
    final doctor = _doctorProfile;
    if (doctor == null) {
      return const SizedBox.shrink();
    }

    final isHome = _visitType == 'Home Visit';
    final distanceApplied =
        isHome && _distanceKm != null && _distanceCharge > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fee Preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildFeeRow(
              isHome ? 'Home Visit Base Fee' : 'Clinic Fee',
              _baseFee,
            ),
            if (distanceApplied) ...[
              const SizedBox(height: 8),
              _buildFeeRow(
                'Distance Charge',
                _distanceCharge,
                trailingNote:
                    '${_distanceKm!.toStringAsFixed(2)} km x Rs ${doctor.perKmCharge!.toStringAsFixed(2)}/km',
              ),
            ],
            const Divider(height: 24),
            _buildFeeRow('Estimated Session Fee', _sessionFee, emphasize: true),
            if (_pricingNote != null) ...[
              const SizedBox(height: 10),
              Text(_pricingNote!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            // Text(
            //  'If the doctor adds a last-minute special treatment such as cupping or needling, that extra charge is applied only to that appointment at completion time.',
            //   style: Theme.of(context).textTheme.bodySmall,
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(
    String label,
    double amount, {
    String? trailingNote,
    bool emphasize = false,
  }) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            trailingNote == null ? label : '$label\n$trailingNote',
            style: style,
          ),
        ),
        const SizedBox(width: 12),
        Text('Rs ${amount.toStringAsFixed(2)}', style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final doctor = args is DoctorArgs
        ? args
        : const DoctorArgs(
            id: 0,
            name: 'Unknown Doctor',
            clinic: '',
            rating: 0,
            age: 0,
            experience: 0,
            address: '',
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Doctor: ${doctor.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Patient Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _selectedDate == null
                  ? 'Select Appointment Date'
                  : '${_selectedDate!.day.toString().padLeft(2, '0')}-'
                        '${_selectedDate!.month.toString().padLeft(2, '0')}-'
                        '${_selectedDate!.year}',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.access_time_outlined),
            label: Text(
              _selectedTime == null
                  ? 'Select Appointment Time'
                  : _selectedTime!.format(context),
            ),
          ),
          const SizedBox(height: 12),
          Text('Visit Type', style: Theme.of(context).textTheme.titleSmall),
          RadioListTile<String>(
            title: const Text('Home Visit'),
            value: 'Home Visit',
            groupValue: _visitType,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _visitType = v);
              _recalculateFeePreview();
            },
          ),
          RadioListTile<String>(
            title: const Text('Clinic Visit'),
            value: 'Clinic Visit',
            groupValue: _visitType,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _visitType = v);
              _recalculateFeePreview();
            },
          ),
          if (_pricingLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else ...[
            const SizedBox(height: 8),
            _buildFeeBreakdownCard(),
          ],

          const SizedBox(height: 8),
          Text(
            'Preferred Payment Mode',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          RadioListTile<String>(
            title: const Text('Cash'),
            value: 'cash',
            groupValue: _paymentMethod,
            onChanged: (v) =>
                setState(() => _paymentMethod = v ?? _paymentMethod),
          ),
          RadioListTile<String>(
            title: const Text('Online'),
            value: 'online',
            groupValue: _paymentMethod,
            onChanged: (v) =>
                setState(() => _paymentMethod = v ?? _paymentMethod),
          ),
          RadioListTile<String>(
            title: const Text('Credit'),
            value: 'credit',
            groupValue: _paymentMethod,
            onChanged: (v) =>
                setState(() => _paymentMethod = v ?? _paymentMethod),
          ),
          RadioListTile<String>(
            title: const Text('Debit'),
            value: 'debit',
            groupValue: _paymentMethod,
            onChanged: (v) =>
                setState(() => _paymentMethod = v ?? _paymentMethod),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _submit(doctor),
            child: const Text('Confirm Appointment'),
          ),
        ],
      ),
    );
  }
}
