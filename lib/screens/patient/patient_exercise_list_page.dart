import 'package:flutter/material.dart';

import '../../models/exercise_library_item.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../widgets/exercise_media_view.dart';

class PatientExerciseListPage extends StatefulWidget {
  const PatientExerciseListPage({super.key});

  @override
  State<PatientExerciseListPage> createState() => _PatientExerciseListPageState();
}

class _PatientExerciseListPageState extends State<PatientExerciseListPage> {
  final ApiService _api = ApiService();

  String _todayDateString() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<_ExerciseListBundle> _loadExercises() async {
    final session = await SessionService().getSession();
    final patientId = session?.patientId;
    if (patientId == null) {
      return const _ExerciseListBundle(exercises: [], dayCompleted: false);
    }

    final exercises = await _api.getPatientTreatmentExercises(patientId);
    final today = await _api.getTodayPatientExercises();
    final log = today['log'] as Map<String, dynamic>?;
    final completed = (log?['completed'] == 1 || log?['completed'] == true);

    return _ExerciseListBundle(
      exercises: exercises,
      dayCompleted: completed,
    );
  }

  ExerciseLibraryItem _toExerciseLibraryItem(Map<String, dynamic> item) {
    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is num) return value.toInt();
      return null;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    return ExerciseLibraryItem(
      id: parseInt(item['exercise_id']) > 0
          ? parseInt(item['exercise_id'])
          : parseInt(item['master_exercise_id']),
      name: (item['exercise_name'] ?? item['name'] ?? '').toString(),
      description: (item['description'] ?? '').toString(),
      demoMediaUrl: (item['demo_media_url'] ?? '').toString(),
      exerciseType: (item['exercise_type'] ?? 'time').toString(),
      recommendedReps: (item['recommended_reps'] ?? '').toString(),
      repCount: parseNullableInt(item['rep_count']),
      defaultDurationSeconds: parseNullableInt(item['default_duration_seconds']),
    );
  }

  Future<void> _startExerciseFlow() async {
    try {
      await _api.startPatientExerciseDay();
      if (!mounted) return;
      final session = await SessionService().getSession();
      final patientId = session?.patientId;
      if (patientId == null) return;
      final assigned = await _api.getPatientTreatmentExercises(patientId);
      if (!mounted || assigned.isEmpty) return;
      Navigator.pushNamed(
        context,
        AppRoutes.patientExerciseCountdown,
        arguments: {
          'patientId': patientId,
          'exercises': assigned,
          'date': _todayDateString(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      if (text.toLowerCase().contains('already completed')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Today's exercises already completed.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to start exercise session')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assigned Exercises')),
      body: FutureBuilder<_ExerciseListBundle>(
        future: _loadExercises(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load exercises'));
          }

          final bundle = snapshot.data;
          final exercises = bundle?.exercises ?? const <Map<String, dynamic>>[];
          if (exercises.isEmpty) {
            return const Center(child: Text('No exercises assigned'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...exercises.map((item) {
                final exercise = _toExerciseLibraryItem(item);
                final title = exercise.name.trim().isEmpty
                    ? 'Exercise ${exercise.id}'
                    : exercise.name.trim();
                final description = exercise.description.trim().isEmpty
                    ? 'No description available'
                    : exercise.description.trim();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.patientExerciseDetail,
                        arguments: exercise,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 74,
                                height: 74,
                                child: ExerciseMediaView(
                                  mediaUrl:
                                      _api.resolveFileUrl(exercise.demoMediaUrl),
                                  width: 74,
                                  height: 74,
                                  borderRadius: 10,
                                  compact: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (exercises.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: (bundle?.dayCompleted ?? false)
                      ? null
                      : _startExerciseFlow,
                  child: Text(
                    (bundle?.dayCompleted ?? false)
                        ? "Today's exercises already completed."
                        : 'Start Exercise',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseListBundle {
  const _ExerciseListBundle({
    required this.exercises,
    required this.dayCompleted,
  });

  final List<Map<String, dynamic>> exercises;
  final bool dayCompleted;
}
