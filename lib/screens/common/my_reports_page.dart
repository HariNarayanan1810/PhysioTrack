import 'package:flutter/material.dart';

import '../../models/user_report.dart';
import '../../services/api_service.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  late Future<List<UserReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getMyReports();
  }

  void _reload() {
    setState(() {
      _future = ApiService().getMyReports();
    });
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'UNDER_REVIEW':
        return Colors.orange;
      case 'ACTION_TAKEN':
        return Colors.green;
      case 'CLOSED':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<UserReport>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('Failed to load reports')),
                ],
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('You have not submitted any reports yet')),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.targetName ?? 'Unknown User',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(item.status)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item.status.replaceAll('_', ' '),
                                style: TextStyle(color: _statusColor(item.status)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Reported ${item.targetRole.toLowerCase()}'),
                        Text('Reason: ${item.reasonCategory}'),
                        Text('Submitted: ${item.createdAt}'),
                        const SizedBox(height: 8),
                        Text(item.description),
                        if ((item.adminNote ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Admin update: ${item.adminNote}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
