import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../widgets/exercise_media_view.dart';

class PatientDailyExercisePage extends StatefulWidget {
  const PatientDailyExercisePage({super.key});

  @override
  State<PatientDailyExercisePage> createState() => _PatientDailyExercisePageState();
}

class _PatientDailyExercisePageState extends State<PatientDailyExercisePage> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _starting = false;
  bool _dayCompleted = false;
  int? _patientId;
  DateTime _currentMonthDate = DateTime(DateTime.now().year, DateTime.now().month);
  List<_DailyExerciseItem> _items = [];
  Set<DateTime> _completedDates = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime? _parseDateOnly(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      if (value.length >= 10) {
        return _dateOnly(DateTime.parse(value.substring(0, 10)));
      }
      return _dateOnly(DateTime.parse(value));
    } catch (_) {
      return null;
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  String _todayDateString() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final session = await SessionService().getSession();
      final patientId = session?.patientId;
      if (patientId == null) {
        if (!mounted) return;
        setState(() {
          _patientId = null;
          _items = [];
          _completedDates = {};
          _dayCompleted = false;
          _loading = false;
        });
        return;
      }

      final exercises = await _api.getPatientTreatmentExercises(patientId);
      final todayData = await _api.getTodayPatientExercises();
      final completedDays = await _api.getPatientExerciseCompletedDays(
        month: _currentMonthDate.month,
        year: _currentMonthDate.year,
      );

      final log = todayData['log'] as Map<String, dynamic>?;
      final dayCompleted = (log?['completed'] == 1 || log?['completed'] == true);

      final parsedDates = <DateTime>{};
      for (final value in completedDays) {
        final parsedDate = _parseDateOnly(value);
        if (parsedDate != null) {
          parsedDates.add(parsedDate);
        }
      }

      final today = _dateOnly(DateTime.now());
      if (dayCompleted &&
          today.month == _currentMonthDate.month &&
          today.year == _currentMonthDate.year) {
        parsedDates.add(today);
      }

      final items = exercises.map((row) {
        return _DailyExerciseItem(
          progressId: _parseInt(row['id']),
          trackingExerciseId: _parseInt(row['exercise_id']) > 0
              ? _parseInt(row['exercise_id'])
              : _parseInt(row['master_exercise_id']),
          name: (row['exercise_name'] ?? row['name'] ?? '').toString(),
          description: (row['description'] ?? '').toString(),
          mediaUrl: (row['demo_media_url'] ?? '').toString(),
          completed:
              row['completed_flag'] == 1 || row['completed_flag'] == true,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _patientId = patientId;
        _items = items;
        _completedDates = parsedDates;
        _dayCompleted = dayCompleted;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load daily exercises')),
      );
    }
  }

  Future<void> _changeMonth(int delta) async {
    final updated = DateTime(_currentMonthDate.year, _currentMonthDate.month + delta);
    setState(() {
      _currentMonthDate = DateTime(updated.year, updated.month);
    });
    await _load();
  }

  Future<void> _startExerciseFlow() async {
    if (_starting || _patientId == null || _items.isEmpty || _dayCompleted) return;

    setState(() => _starting = true);
    try {
      await _api.startPatientExerciseDay();
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.patientExerciseCountdown,
        arguments: {
          'patientId': _patientId,
          'exercises': _items
              .map(
                (item) => {
                  'id': item.progressId,
                  'exercise_id': item.trackingExerciseId,
                  'exercise_name': item.name,
                  'description': item.description,
                  'demo_media_url': item.mediaUrl,
                },
              )
              .toList(),
          'date': _todayDateString(),
        },
      ).then((_) => _load());
    } catch (e) {
      if (!mounted) return;
      final text = e.toString().toLowerCase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text.contains('already completed')
                ? "Today's exercises already completed."
                : 'Unable to start exercise session',
          ),
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  bool _isCompleted(DateTime date) {
    final target = _dateOnly(date);
    return _completedDates.any(
      (value) =>
          value.year == target.year &&
          value.month == target.month &&
          value.day == target.day,
    );
  }

  Widget _mediaPreview(String mediaUrl) {
    final url = _api.resolveFileUrl(mediaUrl);
    return ExerciseMediaView(
      mediaUrl: url,
      width: 84,
      height: 84,
      borderRadius: 10,
      compact: true,
    );
  }

  Widget _calendarWidget() {
    final firstDay = DateTime(_currentMonthDate.year, _currentMonthDate.month, 1);
    final daysInMonth =
        DateTime(_currentMonthDate.year, _currentMonthDate.month + 1, 0).day;
    final leading = firstDay.weekday % 7;
    final cells = <Widget>[];

    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonthDate.year, _currentMonthDate.month, day);
      final done = _isCompleted(date);

      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: done ? Colors.green : Colors.transparent,
            border: Border.all(
              color: done ? Colors.green : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: done ? Colors.white : null,
                fontWeight: done ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: cells,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Exercise')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Exercise')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton(
              onPressed: (_starting || _dayCompleted || _items.isEmpty)
                  ? null
                  : _startExerciseFlow,
              style: FilledButton.styleFrom(
                disabledBackgroundColor:
                    _dayCompleted ? Colors.grey.shade400 : null,
                disabledForegroundColor:
                    _dayCompleted ? Colors.grey.shade800 : null,
              ),
              child: Text(_dayCompleted ? 'Today Completed' : 'Start Exercise'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended Exercises',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      const Text('No active exercises assigned for today')
                    else
                      ..._items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _mediaPreview(item.mediaUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name.trim().isEmpty
                                          ? 'Exercise'
                                          : item.name.trim(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description.trim().isEmpty
                                          ? 'No description available'
                                          : item.description.trim(),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.completed ? 'Completed' : 'Pending',
                                      style: TextStyle(
                                        color: item.completed
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Completion Calendar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left),
                          tooltip: 'Previous month',
                        ),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy').format(_currentMonthDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right),
                          tooltip: 'Next month',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _calendarWidget(),
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

class _DailyExerciseItem {
  const _DailyExerciseItem({
    required this.progressId,
    required this.trackingExerciseId,
    required this.name,
    required this.description,
    required this.mediaUrl,
    required this.completed,
  });

  final int progressId;
  final int trackingExerciseId;
  final String name;
  final String description;
  final String mediaUrl;
  final bool completed;
}
