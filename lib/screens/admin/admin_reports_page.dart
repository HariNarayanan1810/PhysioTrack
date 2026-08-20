import 'package:flutter/material.dart';

import '../../models/user_report.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  final ApiService _api = ApiService();
  late Future<List<UserReport>> _future;
  String _statusFilter = 'ALL';
  String? _targetRole;
  int? _targetDoctorId;
  int? _targetPatientId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _targetRole = args['targetRole']?.toString();
      _targetDoctorId = args['targetDoctorId'] as int?;
      _targetPatientId = args['targetPatientId'] as int?;
    }
    _future = _load();
  }

  Future<List<UserReport>> _load() {
    return _api.getAdminReports(
      status: _statusFilter == 'ALL' ? null : _statusFilter,
      targetRole: _targetRole,
      targetDoctorId: _targetDoctorId,
      targetPatientId: _targetPatientId,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _updateStatus(UserReport item) async {
    final noteCtrl = TextEditingController(text: item.adminNote ?? '');
    var selectedStatus = item.status;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Update Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'SUBMITTED', child: Text('SUBMITTED')),
                  DropdownMenuItem(
                    value: 'UNDER_REVIEW',
                    child: Text('UNDER REVIEW'),
                  ),
                  DropdownMenuItem(
                    value: 'ACTION_TAKEN',
                    child: Text('ACTION TAKEN'),
                  ),
                  DropdownMenuItem(value: 'CLOSED', child: Text('CLOSED')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setLocal(() => selectedStatus = value);
                },
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Admin Note',
                  hintText: 'Optional internal/public summary',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.updateAdminReportStatus(
        reportId: item.id,
        status: selectedStatus,
        adminNote: noteCtrl.text.trim(),
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openTarget(UserReport item) {
    if (item.targetRole.toUpperCase() == 'DOCTOR' && item.targetDoctorId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.adminDoctorProfileDetail,
        arguments: {'doctorId': item.targetDoctorId, 'removedView': false},
      );
      return;
    }
    if (item.targetRole.toUpperCase() == 'PATIENT' && item.targetPatientId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.adminPatientProfileDetail,
        arguments: {'patientId': item.targetPatientId, 'removedView': false},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                DropdownMenuItem(value: 'SUBMITTED', child: Text('Submitted')),
                DropdownMenuItem(
                  value: 'UNDER_REVIEW',
                  child: Text('Under Review'),
                ),
                DropdownMenuItem(
                  value: 'ACTION_TAKEN',
                  child: Text('Action Taken'),
                ),
                DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _statusFilter = value;
                  _future = _load();
                });
              },
              decoration: const InputDecoration(labelText: 'Filter'),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<UserReport>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load reports'));
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('No reports found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.reporterName ?? 'Unknown'} reported ${item.targetName ?? 'Unknown'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('Reason: ${item.reasonCategory}'),
                            Text('Status: ${item.status.replaceAll('_', ' ')}'),
                            Text('Submitted: ${item.createdAt}'),
                            const SizedBox(height: 8),
                            Text(item.description),
                            if ((item.adminNote ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Admin note: ${item.adminNote}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _openTarget(item),
                                  child: const Text('Open Target'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => _updateStatus(item),
                                  child: const Text('Update Status'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
