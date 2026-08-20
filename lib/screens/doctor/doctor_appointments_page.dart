import 'package:flutter/material.dart';

class DoctorAppointmentsPage extends StatelessWidget {
  const DoctorAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appointments = [
      _Appt('Aaravind', 'Scheduled', '09:00 AM'),
      _Appt('Sherill', 'Started', '11:30 AM'),
      _Appt('Praveen', 'Completed', '03:00 PM'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = appointments[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.patient,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusChip(status: item.status),
                      const SizedBox(width: 8),
                      Text(item.time),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Session started for ${item.patient}',
                                ),
                              ),
                            );
                          },
                          child: const Text('Start Session'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Session completed for ${item.patient}',
                                ),
                              ),
                            );
                          },
                          child: const Text('Complete Session'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Appt {
  const _Appt(this.patient, this.status, this.time);

  final String patient;
  final String status;
  final String time;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Scheduled' => Colors.orange,
      'Started' => Colors.blue,
      'Completed' => Colors.green,
      _ => Colors.grey,
    };

    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withOpacity(0.4)),
    );
  }
}
