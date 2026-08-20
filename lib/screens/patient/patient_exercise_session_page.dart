import 'package:flutter/material.dart';

import '../../models/exercise_library_item.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../widgets/exercise_media_view.dart';

class PatientExerciseSessionPage extends StatefulWidget {
  const PatientExerciseSessionPage({super.key});

  @override
  State<PatientExerciseSessionPage> createState() =>
      _PatientExerciseSessionPageState();
}

class _PatientExerciseSessionPageState
    extends State<PatientExerciseSessionPage> {
  final ApiService _api = ApiService();

  bool _submitting = false;

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

  Future<void> _completeExercise({
    required List<Map<String, dynamic>> exercises,
    required int currentIndex,
    required String sessionDate,
  }) async {
    if (_submitting) return;

    final currentExercise = _toExerciseLibraryItem(exercises[currentIndex]);
    setState(() => _submitting = true);

    try {
      await _api.completeOnePatientExercise(
        exerciseId: currentExercise.id,
        date: sessionDate,
      );

      if (!mounted) return;

      final isLast = currentIndex >= exercises.length - 1;
      if (isLast) {
        await _api.completePatientExerciseDay(date: sessionDate);
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.patientExerciseCompletion,
          arguments: {'completedDate': sessionDate},
        );
        return;
      }

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.patientExerciseSession,
        arguments: {
          'exercises': exercises,
          'date': sessionDate,
          'currentIndex': currentIndex + 1,
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update exercise progress')),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map<String, dynamic> ? routeArgs : const {};
    final rawExercises = args['exercises'] as List<dynamic>? ?? const [];
    final currentIndex = (args['currentIndex'] as int?) ?? 0;
    final now = DateTime.now();
    final fallbackDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final sessionDate = (args['date']?.toString() ?? fallbackDate).trim();
    final exercises = rawExercises
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();

    if (exercises.isEmpty || currentIndex < 0 || currentIndex >= exercises.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise Session')),
        body: const Center(child: Text('No exercise session found')),
      );
    }

    final item = _toExerciseLibraryItem(exercises[currentIndex]);
    final mediaUrl = _api.resolveFileUrl(item.demoMediaUrl);
    final type = item.exerciseType.toLowerCase() == 'reps'
        ? 'Repetition Based'
        : 'Time Based';
    final targetText = item.exerciseType.toLowerCase() == 'reps'
        ? (item.recommendedReps.isNotEmpty
              ? item.recommendedReps
              : '${item.repCount ?? 0} reps')
        : '${item.defaultDurationSeconds ?? 0} sec';
    final title =
        item.name.trim().isEmpty ? 'Exercise ${item.id}' : item.name.trim();
    final description = item.description.trim().isEmpty
        ? 'No description available.'
        : item.description.trim();
    final isLastExercise = currentIndex >= exercises.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Session')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4C5C), Color(0xFF2C7A7B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F4C5C).withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExerciseMediaView(
                    mediaUrl: mediaUrl,
                    width: double.infinity,
                    height: 240,
                    borderRadius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    iconColor: Colors.white,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroPill(
                        label: 'Exercise ${currentIndex + 1} of ${exercises.length}',
                      ),
                      const _HeroPill(label: 'Active Session'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Follow the movement carefully and finish this step before moving to the next exercise.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.category_outlined,
                  label: 'Exercise Type',
                  value: type,
                  accent: const Color(0xFF125D98),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.track_changes_outlined,
                  label: 'Target',
                  value: targetText,
                  accent: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F7F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF1B5E7A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: const Color(0xFF2E3A3F),
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting
                ? null
                : () => _completeExercise(
                      exercises: exercises,
                      currentIndex: currentIndex,
                      sessionDate: sessionDate,
                    ),
            child: Text(
              _submitting
                  ? 'Updating...'
                  : isLastExercise
                      ? 'Complete Today\'s Exercise'
                      : 'Mark as Done & Next',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blueGrey.shade700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
