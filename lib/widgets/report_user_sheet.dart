import 'package:flutter/material.dart';

import '../services/api_service.dart';

Future<void> showReportUserSheet({
  required BuildContext context,
  required String targetRole,
  int? targetDoctorId,
  int? targetPatientId,
  required String targetName,
}) async {
  const doctorReasons = <String>[
    'Fake identity or qualification',
    'Unsafe treatment advice',
    'Abusive or rude behaviour',
    'Harassment or inappropriate conduct',
    'Payment fraud or unfair money demand',
    'Repeated no-show or cancellation',
    'Privacy violation',
    'Other',
  ];
  const patientReasons = <String>[
    'Abusive or threatening behaviour',
    'Harassment or inappropriate conduct',
    'Fake or prank booking',
    'Repeated no-show',
    'Payment fraud or refusal',
    'False information or impersonation',
    'Privacy violation',
    'Other',
  ];

  final reasons = targetRole.toUpperCase() == 'DOCTOR'
      ? doctorReasons
      : patientReasons;
  String selectedReason = reasons.first;
  final descriptionCtrl = TextEditingController();
  final api = ApiService();
  var submitting = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Report $targetName',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  items: reasons
                      .map((reason) =>
                          DropdownMenuItem(value: reason, child: Text(reason)))
                      .toList(),
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setSheetState(() => selectedReason = value);
                        },
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  maxLines: 4,
                  enabled: !submitting,
                  decoration: const InputDecoration(
                    labelText: 'Explain what happened',
                    hintText: 'Describe the issue clearly',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final description = descriptionCtrl.text.trim();
                          if (description.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Description is required'),
                              ),
                            );
                            return;
                          }

                          setSheetState(() => submitting = true);
                          try {
                            await api.createUserReport(
                              targetRole: targetRole.toUpperCase(),
                              targetDoctorId: targetDoctorId,
                              targetPatientId: targetPatientId,
                              reasonCategory: selectedReason,
                              description: description,
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report submitted to admin'),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                            setSheetState(() => submitting = false);
                          }
                        },
                  child: Text(submitting ? 'Submitting...' : 'Submit Report'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
