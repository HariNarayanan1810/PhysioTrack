import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';

class ExerciseCompletionScreen extends StatefulWidget {
  const ExerciseCompletionScreen({super.key});

  @override
  State<ExerciseCompletionScreen> createState() =>
      _ExerciseCompletionScreenState();
}

class _ExerciseCompletionScreenState extends State<ExerciseCompletionScreen> {
  final ApiService _api = ApiService();
  Set<DateTime> _completedDates = {};
  bool _loading = true;
  DateTime _currentMonthDate = DateTime(DateTime.now().year, DateTime.now().month);
  String? _forcedCompletedDate;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_forcedCompletedDate != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final forced = args['completedDate']?.toString() ?? '';
      if (forced.trim().isNotEmpty) {
        _forcedCompletedDate = forced.trim();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCompletedDays();
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

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

  Future<void> _loadCompletedDays() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final dates = await _api.getPatientExerciseCompletedDays(
        month: _currentMonthDate.month,
        year: _currentMonthDate.year,
      );

      final parsed = <DateTime>{};
      for (final value in dates) {
        final parsedDate = _parseDateOnly(value);
        if (parsedDate != null) parsed.add(parsedDate);
      }

      final forcedDate = _parseDateOnly(_forcedCompletedDate ?? '');
      if (forcedDate != null &&
          forcedDate.month == _currentMonthDate.month &&
          forcedDate.year == _currentMonthDate.year) {
        parsed.add(forcedDate);
      }

      if (!mounted) return;
      setState(() {
        _completedDates = parsed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    final updated = DateTime(_currentMonthDate.year, _currentMonthDate.month + delta);
    setState(() {
      _currentMonthDate = DateTime(updated.year, updated.month);
    });
    _loadCompletedDays();
  }

  bool _isCompleted(DateTime date) {
    final target = _dateOnly(date);
    return _completedDates.any((d) =>
        d.year == target.year && d.month == target.month && d.day == target.day);
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
      final currentCellDate =
          DateTime(_currentMonthDate.year, _currentMonthDate.month, day);
      final done = _isCompleted(currentCellDate);

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
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Completed')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.celebration, size: 52, color: Colors.orange),
                        const SizedBox(height: 10),
                        Text(
                          'Congratulations!',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text("You have completed today's exercises."),
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
    );
  }
}
