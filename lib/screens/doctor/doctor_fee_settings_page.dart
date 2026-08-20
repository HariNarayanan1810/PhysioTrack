import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/session_service.dart';

class DoctorFeeSettingsPage extends StatefulWidget {
  const DoctorFeeSettingsPage({super.key});

  @override
  State<DoctorFeeSettingsPage> createState() => _DoctorFeeSettingsPageState();
}

class _DoctorFeeSettingsPageState extends State<DoctorFeeSettingsPage> {
  final ApiService _api = ApiService();
  final _clinicFeeCtrl = TextEditingController();
  final _homeVisitBaseFeeCtrl = TextEditingController();
  final _perKmChargeCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int? _doctorId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clinicFeeCtrl.dispose();
    _homeVisitBaseFeeCtrl.dispose();
    _perKmChargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final session = await SessionService().getSession();
      final doctorId = session?.doctorId;
      if (doctorId == null) {
        setState(() {
          _loading = false;
          _error = 'Doctor session not found';
        });
        return;
      }

      final doctor = await _api.getDoctorById(doctorId);
      if (!mounted) return;
      _doctorId = doctorId;
      _clinicFeeCtrl.text = doctor.clinicFee.toStringAsFixed(2);
      _homeVisitBaseFeeCtrl.text = doctor.homeVisitBaseFee.toStringAsFixed(2);
      _perKmChargeCtrl.text = doctor.perKmCharge?.toStringAsFixed(2) ?? '';

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double? _parseOptional(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Future<void> _save() async {
    final doctorId = _doctorId;
    if (doctorId == null || _saving) return;

    final clinicFee = double.tryParse(_clinicFeeCtrl.text.trim());
    final homeVisitBaseFee = double.tryParse(_homeVisitBaseFeeCtrl.text.trim());
    final perKmCharge = _parseOptional(_perKmChargeCtrl.text);

    if (clinicFee == null || clinicFee < 0) {
      _showMessage('Enter a valid clinic fee');
      return;
    }
    if (homeVisitBaseFee == null || homeVisitBaseFee < 0) {
      _showMessage('Enter a valid home visit base fee');
      return;
    }
    if (perKmCharge != null && perKmCharge < 0) {
      _showMessage('Per km charge cannot be negative');
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.updateDoctorPricing(
        doctorId: doctorId,
        clinicFee: clinicFee,
        homeVisitBaseFee: homeVisitBaseFee,
        perKmCharge: perKmCharge,
      );
      if (!mounted) return;
      _showMessage('Pricing updated');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    String hint = '',
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildField(_clinicFeeCtrl, 'Clinic Fee', hint: 'Example: 300'),
                const SizedBox(height: 12),
                _buildField(
                  _homeVisitBaseFeeCtrl,
                  'Home Visit Base Fee',
                  hint: 'Example: 500',
                ),
                const SizedBox(height: 12),
                _buildField(
                  _perKmChargeCtrl,
                  'Per KM Charge (Optional)',
                  hint: 'Example: 10',
                ),
                const SizedBox(height: 20),
                // Card(
                //   child: Padding(
                //     padding: const EdgeInsets.all(16),
                //     child: Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: const [
                //         Text('Pricing Formula'),
                //         SizedBox(height: 8),
                //         Text('Clinic Visit = Clinic Fee'),
                //         Text(
                //           'Home Visit = Home Visit Base Fee + optional distance charge',
                //         ),
                //         Text(
                //           'Special treatment charges are added per appointment when the doctor completes that session.',
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save Pricing'),
                ),
              ],
            ),
    );
  }
}
