import 'package:flutter/material.dart';

import '../../models/payment.dart';
import '../../services/api_service.dart';

class AdminAllPaymentsPage extends StatefulWidget {
  const AdminAllPaymentsPage({super.key});

  @override
  State<AdminAllPaymentsPage> createState() => _AdminAllPaymentsPageState();
}

class _AdminAllPaymentsPageState extends State<AdminAllPaymentsPage> {
  final ApiService _api = ApiService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getAdminPayments();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getAdminPayments();
    });
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Payments')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load payments'));
          }
          final data = snapshot.data ?? <String, dynamic>{};
          final summary =
              data['summary'] as Map<String, dynamic>? ?? <String, dynamic>{};
          final payments = data['payments'] as List<Payment>? ?? <Payment>[];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Earnings',
                        value:
                            'Rs ${_toDouble(summary['total_earnings']).toStringAsFixed(2)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pending Payments',
                        value: '${_toInt(summary['pending_count'])}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (payments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No payments available'),
                    ),
                  )
                else
                  ...payments.map(
                    (payment) => Card(
                      child: ListTile(
                        title: Text(
                          '${payment.patientName} -> ${payment.doctorName}',
                        ),
                        subtitle: Text(
                          '${payment.appointmentDate} ${payment.appointmentTime}\n'
                          'Status: ${payment.paymentStatus.toUpperCase()}',
                        ),
                        trailing: Text('Rs ${payment.amount.toStringAsFixed(2)}'),
                        isThreeLine: true,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
