import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../models/payment.dart';
import '../../services/api_service.dart';

class PatientPaymentDetailsPage extends StatefulWidget {
  const PatientPaymentDetailsPage({super.key});

  @override
  State<PatientPaymentDetailsPage> createState() => _PatientPaymentDetailsPageState();
}

class _PatientPaymentDetailsPageState extends State<PatientPaymentDetailsPage> {
  final ApiService _api = ApiService();
  late final Razorpay _razorpay;

  Payment? _payment;
  bool _paying = false;
  int? _activePaymentId;
  String? _activeOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_payment != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Payment) {
      _payment = args;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _payNow() async {
    final payment = _payment;
    if (payment == null) return;

    setState(() => _paying = true);
    try {
      final order = await _api.createPaymentOrder(
        paymentId: payment.id,
        amount: payment.amount,
      );

      final orderId = (order['razorpay_order_id'] ?? '').toString();
      final key = (order['key'] ?? '').toString();
      final amount = (order['amount'] as num?)?.toInt() ?? (payment.amount * 100).toInt();

      if (key.isEmpty || orderId.isEmpty) {
        throw Exception('Invalid Razorpay order response');
      }

      _activePaymentId = payment.id;
      _activeOrderId = orderId;

      if (kIsWeb) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Razorpay popup is not available on Flutter web build. Use Android emulator/device.'),
          ),
        );
        setState(() => _paying = false);
        return;
      }

      final options = {
        'key': key,
        'amount': amount,
        'name': 'PhysioTrack',
        'description': 'Physiotherapy Session Payment',
        'order_id': orderId,
        'prefill': {
          'contact': '',
          'email': '',
        },
      };

      _razorpay.open(options);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _paying = false);
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = _activePaymentId;
    final orderId = response.orderId ?? _activeOrderId ?? '';
    final razorpayPaymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';

    if (paymentId == null || orderId.isEmpty || razorpayPaymentId.isEmpty || signature.isEmpty) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid payment success response')),
      );
      return;
    }

    try {
      await _api.confirmPayment(
        paymentId: paymentId,
        razorpayOrderId: orderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: signature,
      );
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _onPaymentError(PaymentFailureResponse _) async {
    final paymentId = _activePaymentId;
    if (paymentId != null) {
      try {
        await _api.failPayment(paymentId: paymentId);
      } catch (_) {
        // Ignore fail-update errors and still show UI feedback.
      }
    }
    if (!mounted) return;
    setState(() => _paying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment failed or cancelled')),
    );
  }

  void _onExternalWallet(ExternalWalletResponse _) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('External wallet selected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    if (payment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Billing Details')),
        body: const Center(child: Text('Payment details not available')),
      );
    }

    final status = payment.paymentStatus.toUpperCase();
    final canPay = status == 'PENDING' || status == 'FAILED';

    return Scaffold(
      appBar: AppBar(title: const Text('Billing Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Doctor Name: ${payment.doctorName}'),
                  const SizedBox(height: 8),
                  Text('Patient Name: ${payment.patientName}'),
                  const SizedBox(height: 8),
                  Text('Appointment: ${payment.appointmentDate} ${payment.appointmentTime}'),
                  const SizedBox(height: 8),
                  Text('Consultation Fee: Rs ${payment.amount.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Text('Payment Method: ${payment.paymentMethod.toUpperCase()}'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _paying || !canPay ? null : _payNow,
            child: _paying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(canPay ? 'Pay Rs ${payment.amount.toStringAsFixed(0)}' : 'Already Paid'),
          ),
        ],
      ),
    );
  }
}
