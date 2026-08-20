import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../models/doctor_patient.dart';
import '../../models/exercise_library_item.dart';
import '../../services/api_service.dart';
import '../../widgets/report_user_sheet.dart';

class DoctorPatientDetailPage extends StatefulWidget {
  const DoctorPatientDetailPage({super.key});

  @override
  State<DoctorPatientDetailPage> createState() => _DoctorPatientDetailPageState();
}

class _DoctorPatientDetailPageState extends State<DoctorPatientDetailPage> {
  final ApiService _api = ApiService();
  final TextEditingController _problemCtrl = TextEditingController();
  final TextEditingController _suggestedCtrl = TextEditingController();

  int? _doctorId;
  int? _patientId;
  bool _loading = true;
  bool _savingProblem = false;
  bool _uploadingMedia = false;
  bool _problemEditable = false;
  DoctorPatientDetail? _detail;

  @override
  void dispose() {
    _problemCtrl.dispose();
    _suggestedCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_doctorId != null && _patientId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _doctorId = args['doctorId'] as int?;
      _patientId = args['patientId'] as int?;
    }
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (_doctorId == null || _patientId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final detail = await _api.getDoctorPatientDetail(
        doctorId: _doctorId!,
        patientId: _patientId!,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _problemCtrl.text = detail.problemDescription;
        _suggestedCtrl.text =
            detail.suggestedNextAppointment?.replaceFirst('T', ' ') ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _pickSuggestedDateTime() async {
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
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    _suggestedCtrl.text = '${dt.year}-$mm-$dd $hh:$min:00';
    setState(() {});
  }

  Future<void> _saveProblem() async {
    if (_doctorId == null || _patientId == null) return;
    final text = _problemCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Problem description cannot be empty')),
      );
      return;
    }

    setState(() => _savingProblem = true);
    try {
      if (_detail?.noteId == null) {
        await _api.createDoctorPatientProblem(
          doctorId: _doctorId!,
          patientId: _patientId!,
          problemDescription: text,
          suggestedNextAppointment: _suggestedCtrl.text.trim().isEmpty
              ? null
              : _suggestedCtrl.text.trim(),
        );
      } else {
        await _api.updateDoctorPatientProblem(
          doctorId: _doctorId!,
          patientId: _patientId!,
          problemDescription: text,
          suggestedNextAppointment: _suggestedCtrl.text.trim().isEmpty
              ? null
              : _suggestedCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      setState(() => _problemEditable = false);
      await _loadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Problem description saved')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save problem description')),
      );
    } finally {
      if (mounted) setState(() => _savingProblem = false);
    }
  }

  Future<void> _pickAndUploadMedia() async {
    if (_doctorId == null || _patientId == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf', 'docx'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final Uint8List? bytes = picked.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read selected file')),
      );
      return;
    }

    setState(() => _uploadingMedia = true);
    try {
      await _api.uploadDoctorPatientMediaBytes(
        doctorId: _doctorId!,
        patientId: _patientId!,
        bytes: bytes,
        fileName: picked.name,
      );
      if (!mounted) return;
      await _loadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File uploaded successfully')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload file')),
      );
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Future<void> _deleteMedia(int id) async {
    if (_doctorId == null) return;
    try {
      await _api.deleteDoctorPatientMedia(doctorId: _doctorId!, mediaId: id);
      if (!mounted) return;
      await _loadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete file')),
      );
    }
  }

  Future<void> _showAddItemDialog({
    required String title,
    required Future<void> Function(String) onSave,
    String initialValue = '',
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Enter text'),
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
    await onSave(value);
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
      await _loadDetail();
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
      if (catalog.isEmpty) {
        scaffold.showSnackBar(
          const SnackBar(content: Text('No exercises available in database')),
        );
        return;
      }

      final selected = await showModalBottomSheet<ExerciseLibraryItem>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: catalog.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = catalog[index];
              final type = item.exerciseType.toLowerCase() == 'reps'
                  ? (item.recommendedReps.isNotEmpty
                        ? item.recommendedReps
                        : '${item.repCount ?? 0} reps')
                  : '${item.defaultDurationSeconds ?? 0} sec';
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '${item.description.isEmpty ? 'No description' : item.description}\nTarget: $type',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, item),
              );
            },
          );
        },
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

  Future<void> _deleteExercise(int id) async {
    if (_doctorId == null) return;
    try {
      await _api.deleteDoctorPatientExercise(
        doctorId: _doctorId!,
        exerciseId: id,
      );
      if (!mounted) return;
      await _loadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise deleted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete exercise')),
      );
    }
  }

  Future<void> _addAdvice(String text) async {
    if (_doctorId == null || _patientId == null) return;
    try {
      await _api.addDoctorPatientAdvice(
        doctorId: _doctorId!,
        patientId: _patientId!,
        adviceText: text,
      );
      if (!mounted) return;
      await _loadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advice saved')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save advice')),
      );
    }
  }

  Future<void> _deleteAdvice(int id) async {
    if (_doctorId == null) return;
    try {
      await _api.deleteDoctorPatientAdvice(
        doctorId: _doctorId!,
        adviceId: id,
      );
      if (!mounted) return;
      await _loadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advice deleted')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete advice')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient Details')),
        body: const Center(child: Text('Unable to load patient detail')),
      );
    }

    final imageUrl = _api.resolveFileUrl(detail.profileImage);

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                        child: imageUrl.isEmpty
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          detail.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Email: ${detail.email}'),
                  Text('Age: ${detail.age}'),
                  Text('State: ${detail.state.isEmpty ? '-' : detail.state}'),
                  Text('City: ${detail.city.isEmpty ? '-' : detail.city}'),
                  Text('Address: ${detail.address.isEmpty ? '-' : detail.address}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Progress',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'View the patient exercise calendar and current exercise list.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.doctorPatientDailyProgress,
                      arguments: {
                        'doctorId': _doctorId,
                        'patientId': _patientId,
                        'patientName': detail.name,
                      },
                    ),
                    child: const Text('Daily Progress'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () => showReportUserSheet(
                  context: context,
                  targetRole: 'PATIENT',
                  targetPatientId: detail.patientId,
                  targetName: detail.name,
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report Patient'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Problem Description',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: () => setState(() => _problemEditable = !_problemEditable),
                        icon: Icon(_problemEditable ? Icons.close : Icons.edit_outlined),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _problemCtrl,
                    maxLines: 4,
                    enabled: _problemEditable,
                    decoration: const InputDecoration(
                      hintText: 'Enter problem description',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _suggestedCtrl,
                    readOnly: true,
                    enabled: _problemEditable,
                    onTap: _problemEditable ? _pickSuggestedDateTime : null,
                    decoration: const InputDecoration(
                      labelText: 'Suggested Next Appointment',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _savingProblem || !_problemEditable ? null : _saveProblem,
                      child: _savingProblem
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Media Upload',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      OutlinedButton(
                        onPressed: _uploadingMedia ? null : _pickAndUploadMedia,
                        child: _uploadingMedia
                            ? const Text('Uploading...')
                            : const Text('Upload'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (detail.media.isEmpty)
                    const Text('No media files uploaded')
                  else
                    ...detail.media.map(
                      (m) {
                        final url = _api.resolveFileUrl(m.filePath);
                        final isImage = m.fileType == 'image';
                        return ListTile(
                          leading: isImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                )
                              : Icon(
                                  m.fileType == 'pdf'
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.description_outlined,
                                ),
                          title: Text(m.filePath.split('/').last),
                          subtitle: Text(m.fileType.toUpperCase()),
                          onTap: isImage
                              ? () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      content: Image.network(
                                        url,
                                        fit: BoxFit.contain,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              : null,
                          trailing: IconButton(
                            onPressed: () => _deleteMedia(m.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Treatment / Solution',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      FilledButton.tonal(
                        onPressed: _pickExerciseFromDatabase,
                        child: const Text('Add Exercise'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (detail.exercises.isEmpty)
                    const Text('No exercises added')
                  else
                    ...detail.exercises.map(
                      (e) => ListTile(
                        leading: const Icon(Icons.fitness_center_outlined),
                        title: Text(e.value),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed: () => _showAddItemDialog(
                                title: 'Edit Exercise',
                                initialValue: e.value,
                                onSave: (value) async {
                                  await _deleteExercise(e.id);
                                  await _addExercise(value);
                                },
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () => _deleteExercise(e.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Advice',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      FilledButton.tonal(
                        onPressed: () => _showAddItemDialog(
                          title: 'Add Advice',
                          onSave: _addAdvice,
                        ),
                        child: const Text('Add Advice'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (detail.advice.isEmpty)
                    const Text('No advice added')
                  else
                    ...detail.advice.map(
                      (a) => ListTile(
                        leading: const Icon(Icons.tips_and_updates_outlined),
                        title: Text(a.value),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              onPressed: () => _showAddItemDialog(
                                title: 'Edit Advice',
                                initialValue: a.value,
                                onSave: (value) async {
                                  await _deleteAdvice(a.id);
                                  await _addAdvice(value);
                                },
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () => _deleteAdvice(a.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
