import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/doctor_patient.dart';
import '../../models/exercise_library_item.dart';
import '../../services/api_service.dart';

class DoctorPatientDailyProgressPage extends StatefulWidget {
  const DoctorPatientDailyProgressPage({super.key});

  @override
  State<DoctorPatientDailyProgressPage> createState() =>
      _DoctorPatientDailyProgressPageState();
}

class _DoctorPatientDailyProgressPageState
    extends State<DoctorPatientDailyProgressPage> {
  final ApiService _api = ApiService();

  int? _doctorId;
  int? _patientId;
  String _patientName = 'Patient';
  bool _loading = true;
  DateTime _currentMonthDate = DateTime(DateTime.now().year, DateTime.now().month);
  DoctorPatientDetail? _detail;
  Set<DateTime> _completedDates = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_doctorId != null && _patientId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _doctorId = args['doctorId'] as int?;
      _patientId = args['patientId'] as int?;
      _patientName = (args['patientName'] ?? 'Patient').toString();
    }
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

  Future<void> _load() async {
    if (_doctorId == null || _patientId == null) {
      setState(() => _loading = false);
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final detail = await _api.getDoctorPatientDetail(
        doctorId: _doctorId!,
        patientId: _patientId!,
      );
      final completedDays = await _api.getDoctorPatientExerciseCompletedDays(
        doctorId: _doctorId!,
        patientId: _patientId!,
        month: _currentMonthDate.month,
        year: _currentMonthDate.year,
      );

      final parsedDates = <DateTime>{};
      for (final value in completedDays) {
        final date = _parseDateOnly(value);
        if (date != null) {
          parsedDates.add(date);
        }
      }

      if (!mounted) return;
      setState(() {
        _detail = detail;
        _completedDates = parsedDates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _showAddExerciseDialog() async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Exercise'),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Enter exercise name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    await _addExercise(value);
  }

  Future<void> _addExercise(String text) async {
    if (_doctorId == null || _patientId == null) return;
    try {
      await _api.addDoctorPatientExercise(
        doctorId: _doctorId!,
        patientId: _patientId!,
        exerciseName: text,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise saved')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save exercise')),
      );
    }
  }

  Future<void> _pickExerciseFromDatabase() async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final source = await _api.getExerciseLibrary();
      if (!mounted) return;
      if (source.isEmpty) {
        scaffold.showSnackBar(
          const SnackBar(content: Text('No exercises available in database')),
        );
        return;
      }

      final unique = <String, ExerciseLibraryItem>{};
      for (final item in source) {
        final key = item.name.trim().toLowerCase();
        if (key.isEmpty) continue;
        unique.putIfAbsent(key, () => item);
      }
      final catalog = unique.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final selected = await showModalBottomSheet<ExerciseLibraryItem>(
        context: context,
        showDragHandle: true,
        builder: (context) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: catalog.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = catalog[index];
            return ListTile(
              title: Text(item.name),
              subtitle: Text(
                item.description.isEmpty ? 'No description' : item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(context, item),
            );
          },
        ),
      );

      if (selected == null) return;
      await _addExercise(selected.name);
    } catch (_) {
      if (!mounted) return;
      scaffold.showSnackBar(
        const SnackBar(content: Text('Failed to load exercise catalog')),
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

  bool _isCompleted(DateTime date) {
    final target = _dateOnly(date);
    return _completedDates.any(
      (value) =>
          value.year == target.year &&
          value.month == target.month &&
          value.day == target.day,
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
        appBar: AppBar(title: const Text('Daily Progress')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final detail = _detail;
    final exercises = detail?.exercises ?? const <DoctorPatientItem>[];

    return Scaffold(
      appBar: AppBar(title: Text('Daily Progress - $_patientName')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exercises',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: _showAddExerciseDialog,
                              child: const Text('Add Manually'),
                            ),
                            FilledButton.tonal(
                              onPressed: _pickExerciseFromDatabase,
                              child: const Text('Add Exercise'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (exercises.isEmpty)
                      const Text('No exercises added')
                    else
                      ...exercises.map(
                        (exercise) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.fitness_center_outlined),
                          title: Text(exercise.value),
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
