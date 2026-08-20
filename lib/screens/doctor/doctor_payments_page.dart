import 'package:flutter/material.dart';

import '../../models/payment.dart';
import '../../services/api_service.dart';

class DoctorPaymentsPage extends StatefulWidget {
  const DoctorPaymentsPage({super.key});

  @override
  State<DoctorPaymentsPage> createState() => _DoctorPaymentsPageState();
}

class _DoctorPaymentsPageState extends State<DoctorPaymentsPage> {
  final ApiService _api = ApiService();
  late Future<List<Payment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getDoctorPayments();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getDoctorPayments();
    });
  }

  Future<void> _markPaid(Payment payment) async {
    try {
      await _api.markPaymentPaid(payment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment marked paid')));
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark payment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: FutureBuilder<List<Payment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load payments'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No payments yet'));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final payment = items[index];
                final isPaid = payment.paymentStatus.toLowerCase() == 'paid';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payment.patientName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${payment.appointmentDate} ${payment.appointmentTime}',
                              ),
                              Text(
                                'Amount: Rs ${payment.amount.toStringAsFixed(2)}',
                              ),
                              Text(
                                'Status: ${payment.paymentStatus.toUpperCase()}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isPaid ? null : () => _markPaid(payment),
                          child: const Text('Mark Paid'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
