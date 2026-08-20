import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class PatientTreatmentPlanPage extends StatefulWidget {
  const PatientTreatmentPlanPage({super.key});

  @override
  State<PatientTreatmentPlanPage> createState() => _PatientTreatmentPlanPageState();
}

class _PatientTreatmentPlanPageState extends State<PatientTreatmentPlanPage> {
  final ApiService _api = ApiService();
  int? _patientId;
  late Future<_TreatmentBundle> _future;

  String _todayDateString() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void dispose() => super.dispose();

  Future<_TreatmentBundle> _loadData() async {
    final session = await SessionService().getSession();
    final patientId = session?.patientId;
    _patientId = patientId;
    if (patientId == null) {
      return const _TreatmentBundle(treatment: {}, exercises: []);
    }
    final treatment = await _api.getPatientTreatment(patientId);
    final exercises = await _api.getPatientTreatmentExercises(patientId);
    final liveTracking = await _api.getPatientHomeVisitTracking(patientId);
    final today = await _api.getTodayPatientExercises();
    final log = today['log'] as Map<String, dynamic>?;
    final dayCompleted = (log?['completed'] == 1 || log?['completed'] == true);
    return _TreatmentBundle(
      treatment: treatment,
      exercises: exercises,
      dayCompleted: dayCompleted,
      liveTracking: liveTracking,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadData();
    });
  }

  Future<void> _markExerciseDone(int id, bool value) async {
    if (_patientId == null) return;
    try {
      await _api.markPatientExerciseDone(
        exerciseId: id,
        patientId: _patientId!,
        completed: value,
      );
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise progress updated')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update progress')),
      );
    }
  }

  Future<void> _startExercise() async {
    if (_patientId == null) return;
    final snapshot = await _future;
    final assigned = snapshot.exercises;
    if (assigned.isEmpty) return;
    try {
      await _api.startPatientExerciseDay();
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.patientExerciseCountdown,
        arguments: {
          'patientId': _patientId,
          'exercises': assigned,
          'date': _todayDateString(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      final text = e.toString().toLowerCase();
      if (text.contains('already completed')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Today's exercises already completed.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start exercise session')),
        );
      }
    }
  }

  Future<void> _confirmAppointment(int treatmentId) async {
    if (_patientId == null) return;
    try {
      await _api.confirmSuggestedAppointment(
        treatmentId: treatmentId,
        patientId: _patientId!,
      );
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment confirmed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to confirm appointment')),
      );
    }
  }

  Future<void> _rescheduleAppointment(int treatmentId) async {
    if (_patientId == null) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final formatted = '${dt.year}-$month-$day $hour:$minute:00';

    try {
      await _api.rescheduleSuggestedAppointment(
        treatmentId: treatmentId,
        patientId: _patientId!,
        suggestedNextAppointment: formatted,
      );
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment suggestion rescheduled')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reschedule suggestion')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Treatment Plan')),
      body: FutureBuilder<_TreatmentBundle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load treatment plan'));
          }
          final data = snapshot.data ?? const _TreatmentBundle(treatment: {}, exercises: []);
          final treatment = data.treatment;
          final exercises = data.exercises;

          final problem = (treatment['problem_description'] ?? '').toString();
          final advice = (treatment['advice_notes'] ?? '').toString();
          final lastVisit = (treatment['last_visit_date'] ?? '').toString();
          final suggestion = (treatment['suggested_next_appointment'] ?? '').toString();
          final treatmentIdValue = treatment['id'];
          final treatmentId = treatmentIdValue is int
              ? treatmentIdValue
              : int.tryParse('${treatmentIdValue ?? ''}');
          final liveTracking = data.liveTracking;
          final trackingStatus = (liveTracking?['status'] ?? '').toString().toUpperCase();
          final trackingEnabled =
              liveTracking?['live_tracking_enabled'] == true ||
              liveTracking?['live_tracking_enabled'] == 1;
          final arrivalStatus = liveTracking == null
              ? 'Doctor Starting Visits'
              : trackingEnabled && trackingStatus == 'APPROVED'
                  ? 'Doctor On The Way'
                  : trackingStatus == 'IN_PROGRESS'
                      ? 'Doctor In Session'
                      : trackingStatus == 'COMPLETED'
                          ? 'Visit Completed'
                          : 'Doctor Starting Visits';
          final etaRaw = liveTracking?['current_eta_minutes'];
          final eta = etaRaw is int ? etaRaw : int.tryParse('${etaRaw ?? ''}');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Problem / Diagnosis',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(problem.isEmpty ? 'No diagnosis added yet' : problem),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Exercises',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (exercises.isEmpty)
                        const Text('No exercises assigned yet')
                      else
                        ...exercises.map((e) {
                          final idRaw = e['id'];
                          final id = idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0;
                          final done = (e['completed_flag'] == 1 || e['completed_flag'] == true);
                          return CheckboxListTile(
                            value: done,
                            onChanged: (v) => _markExerciseDone(id, v ?? false),
                            title: Text((e['exercise_name'] ?? '').toString()),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }),
                      if (exercises.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: data.dayCompleted ? null : _startExercise,
                          child: Text(
                            data.dayCompleted
                                ? "Today's exercises already completed."
                                : 'Start Exercise',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advice Given by Doctor',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(advice.isEmpty ? 'No advice added yet' : advice),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text('Last Visit Date'),
                  subtitle: Text(lastVisit.isEmpty ? 'No completed visit yet' : lastVisit),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Appointment Suggestion',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        suggestion.isEmpty
                            ? 'No suggestion available'
                            : suggestion.replaceFirst('T', ' '),
                      ),
                      if (suggestion.isNotEmpty && treatmentId != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _confirmAppointment(treatmentId),
                                child: const Text('Confirm Appointment'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _rescheduleAppointment(treatmentId),
                                child: const Text('Reschedule'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor Arrival Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Status: $arrivalStatus'),
                      Text('Current ETA: ${eta != null ? '$eta min' : '--'}'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.patientLiveTracking,
                        ),
                        icon: const Icon(Icons.location_searching_outlined),
                        label: const Text('Track Live'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TreatmentBundle {
  const _TreatmentBundle({
    required this.treatment,
    required this.exercises,
    this.dayCompleted = false,
    this.liveTracking,
  });

  final Map<String, dynamic> treatment;
  final List<Map<String, dynamic>> exercises;
  final bool dayCompleted;
  final Map<String, dynamic>? liveTracking;
}
