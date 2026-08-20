import 'package:flutter/material.dart';

import '../../models/appointment.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

class DoctorAppointmentsTabbedPage extends StatefulWidget {
  const DoctorAppointmentsTabbedPage({super.key});

  @override
  State<DoctorAppointmentsTabbedPage> createState() =>
      _DoctorAppointmentsTabbedPageState();
}

class _DoctorAppointmentsTabbedPageState
    extends State<DoctorAppointmentsTabbedPage> {
  final ApiService _api = ApiService();
  List<Appointment> _requests = [];
  List<Appointment> _active = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await SessionService().getSession();
      final doctorId = session?.doctorId;
      if (doctorId == null) {
        setState(() {
          _error = 'Doctor session not found';
          _loading = false;
        });
        return;
      }

      final data = await _api.getAppointments(doctorId: doctorId);
      setState(() {
        _requests =
            data.where((a) => a.status == 'REQUESTED').toList(growable: false);
        _active =
            data.where((a) => a.status == 'APPROVED').toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load appointments';
        _loading = false;
      });
    }
  }

  Future<void> _approve(Appointment appt) async {
    try {
      await _api.updateAppointmentStatus(
        appointmentId: appt.id,
        status: 'APPROVED',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment approved')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve appointment')),
      );
    }
  }

  Future<void> _complete(Appointment appt) async {
    final specialSession = await _showSpecialFeeDialog(appt);
    if (!mounted || specialSession == null) return;
    try {
      await _api.updateAppointmentStatus(
        appointmentId: appt.id,
        status: 'COMPLETED',
        isSpecialSession: specialSession.isSpecialSession,
        specialFeeAmount: specialSession.specialFeeAmount,
        specialFeeReason: specialSession.specialFeeReason,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment completed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to complete appointment')),
      );
    }
  }

  Future<void> _reject(Appointment appt) async {
    try {
      await _api.updateAppointmentStatus(
        appointmentId: appt.id,
        status: 'REJECTED',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment rejected')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject appointment')),
      );
    }
  }

  Future<_SpecialSessionInput?> _showSpecialFeeDialog(Appointment appt) async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isSpecial = false;
    String? localError;

    final result = await showDialog<_SpecialSessionInput>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Complete ${appt.patientName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Base fee: Rs ${(appt.sessionFee ?? 0).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: isSpecial,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Add special treatment charge'),
                    subtitle: const Text(
                      'Use this only if the patient needed an extra tool or advanced treatment.',
                    ),
                    onChanged: (value) {
                      setStateDialog(() {
                        isSpecial = value ?? false;
                        localError = null;
                      });
                    },
                  ),
                  if (isSpecial) ...[
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Special charge amount',
                        hintText: 'Example: 150',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Example: Cupping therapy',
                      ),
                    ),
                  ],
                  if (localError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!isSpecial) {
                      Navigator.pop(
                        context,
                        const _SpecialSessionInput(
                          isSpecialSession: false,
                        ),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountCtrl.text.trim());
                    final reason = reasonCtrl.text.trim();
                    if (amount == null || amount < 0) {
                      setStateDialog(() {
                        localError = 'Enter a valid special charge amount';
                      });
                      return;
                    }
                    if (reason.isEmpty) {
                      setStateDialog(() {
                        localError = 'Enter a short reason for the extra charge';
                      });
                      return;
                    }

                    Navigator.pop(
                      context,
                      _SpecialSessionInput(
                        isSpecialSession: true,
                        specialFeeAmount: amount,
                        specialFeeReason: reason,
                      ),
                    );
                  },
                  child: const Text('Complete'),
                ),
              ],
            );
          },
        );
      },
    );

    amountCtrl.dispose();
    reasonCtrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Active'),
              Tab(text: 'Home Visit'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : TabBarView(
                    children: [
                      _RequestsTab(
                        items: _requests,
                        onApprove: _approve,
                        onReject: _reject,
                      ),
                      _ActiveTab(items: _active, onComplete: _complete),
                      _HomeVisitTab(
                        items:
                            _active.where((e) => e.visitType == 'HOME').toList(),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _SpecialSessionInput {
  const _SpecialSessionInput({
    required this.isSpecialSession,
    this.specialFeeAmount,
    this.specialFeeReason,
  });

  final bool isSpecialSession;
  final double? specialFeeAmount;
  final String? specialFeeReason;
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.items,
    required this.onApprove,
    required this.onReject,
  });

  final List<Appointment> items;
  final Future<void> Function(Appointment) onApprove;
  final Future<void> Function(Appointment) onReject;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No appointment requests'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.patientName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('Date: ${item.appointmentDate}'),
                Text('Time: ${item.appointmentTime}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onReject(item),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async => onApprove(item),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActiveTab extends StatelessWidget {
  const _ActiveTab({required this.items, required this.onComplete});

  final List<Appointment> items;
  final Future<void> Function(Appointment) onComplete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No active appointments'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.patientName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('${item.appointmentDate} - ${item.appointmentTime}'),
                      Text(item.visitType == 'HOME' ? 'Home Visit' : 'Clinic Visit'),
                      if (item.sessionFee != null)
                        Text('Session Fee: Rs ${item.sessionFee!.toStringAsFixed(2)}'),
                      if (item.isSpecialSession && item.specialFeeAmount != null)
                        Text(
                          'Special Charge: Rs ${item.specialFeeAmount!.toStringAsFixed(2)}'
                          '${item.specialFeeReason?.isNotEmpty == true ? ' (${item.specialFeeReason})' : ''}',
                        ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => onComplete(item),
                  child: const Text('Complete'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeVisitTab extends StatelessWidget {
  const _HomeVisitTab({required this.items});

  final List<Appointment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No home visits scheduled'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            title: Text(item.patientName),
            subtitle: const Text('Home visit address (from patient profile)'),
            trailing: Text(item.appointmentTime),
          ),
        );
      },
    );
  }
}
