import 'package:flutter/material.dart';

import '../../models/payment.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

class PatientPaymentHistoryPage extends StatefulWidget {
  const PatientPaymentHistoryPage({super.key});

  @override
  State<PatientPaymentHistoryPage> createState() =>
      _PatientPaymentHistoryPageState();
}

class _PatientPaymentHistoryPageState extends State<PatientPaymentHistoryPage> {
  final ApiService _api = ApiService();
  late Future<List<Payment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getPatientPayments();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getPatientPayments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: FutureBuilder<List<Payment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load payment history'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No payment records found'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final payment = items[index];
                final status = payment.paymentStatus.toUpperCase();
                final isPending = status == 'PENDING' || status == 'FAILED';
                final Color statusColor = status == 'PAID'
                    ? Colors.green
                    : status == 'FAILED'
                        ? Colors.red
                        : Colors.orange;
                return Card(
                  child: InkWell(
                    onTap: isPending
                        ? () async {
                            final result = await Navigator.pushNamed(
                              context,
                              AppRoutes.patientPaymentDetails,
                              arguments: payment,
                            );
                            if (result == true) {
                              await _reload();
                            }
                          }
                        : null,
                    child: ListTile(
                      title: Text(payment.doctorName),
                      subtitle: Text(
                        '${payment.appointmentDate} ${payment.appointmentTime}\n'
                        'Method: ${payment.paymentMethod.toUpperCase()}'
                        '${isPending ? '\nTap to pay now' : ''}',
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Rs ${payment.amount.toStringAsFixed(2)}'),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      minVerticalPadding: 10,
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
