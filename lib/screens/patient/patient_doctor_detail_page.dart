import 'package:flutter/material.dart';

import '../../models/doctor.dart';
import '../../models/review.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../widgets/report_user_sheet.dart';
import 'patient_clinic_map_page.dart';

class PatientDoctorDetailPage extends StatefulWidget {
  const PatientDoctorDetailPage({super.key});

  @override
  State<PatientDoctorDetailPage> createState() =>
      _PatientDoctorDetailPageState();
}

class _PatientDoctorDetailPageState extends State<PatientDoctorDetailPage> {
  final ApiService _api = ApiService();
  late Future<Doctor> _doctorFuture;
  late Future<List<Review>> _reviewsFuture;
  DoctorArgs? _args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args != null) return;

    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs is! DoctorArgs) return;

    _args = rawArgs;
    _doctorFuture = _api.getDoctorById(rawArgs.id);
    _reviewsFuture = _api.getReviews(rawArgs.id);
  }

  Future<void> _reloadReviews() async {
    final args = _args;
    if (args == null) return;
    setState(() {
      _reviewsFuture = _api.getReviews(args.id);
    });
    await _reviewsFuture;
  }

  void _openReviewSheet(Doctor doctor) {
    int rating = 0;
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Write a Review',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setLocal) {
                  return Row(
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return IconButton(
                        onPressed: () => setLocal(() => rating = value),
                        icon: Icon(
                          value <= rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  );
                },
              ),
              TextField(
                controller: controller,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Your review'),
              ),
              FilledButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (rating == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a rating')),
                    );
                    return;
                  }
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Review is required')),
                    );
                    return;
                  }

                  final session = await SessionService().getSession();
                  final patientName = (session?.name.isNotEmpty == true)
                      ? session!.name
                      : 'Patient';

                  try {
                    await _api.createReview(
                      doctorId: doctor.id,
                      patientId: session?.patientId,
                      patientName: patientName,
                      rating: rating.toDouble(),
                      reviewText: text,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _reloadReviews();
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to submit review')),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    if (args == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Details')),
        body: const Center(child: Text('Doctor details not available')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Details')),
      body: FutureBuilder<Doctor>(
        future: _doctorFuture,
        builder: (context, doctorSnapshot) {
          if (doctorSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (doctorSnapshot.hasError || !doctorSnapshot.hasData) {
            return const Center(child: Text('Failed to load doctor details'));
          }

          final doctor = doctorSnapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: doctor.profileImageUrl.isNotEmpty
                            ? NetworkImage(doctor.profileImageUrl)
                            : null,
                        child: doctor.profileImageUrl.isEmpty
                            ? const Icon(Icons.medical_services_outlined, size: 32)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text('Age: ${doctor.age} - Exp: ${doctor.yearsOfExperience} yrs'),
                            Text('Clinic: ${doctor.clinicName}'),
                            if (doctor.latitude != 0 && doctor.longitude != 0)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.patientClinicMap,
                                    arguments: PatientClinicMapArgs(
                                      doctorName: doctor.name,
                                      clinicName: doctor.clinicName,
                                      latitude: doctor.latitude,
                                      longitude: doctor.longitude,
                                      address: doctor.clinicAddress,
                                      city: doctor.city,
                                    ),
                                  ),
                                  icon: const Icon(Icons.map_outlined, size: 18),
                                  label: const Text('Show on Map'),
                                ),
                              ),
                            if (doctor.clinicAddress.isNotEmpty)
                              Text('Address: ${doctor.clinicAddress}'),
                            if (doctor.city.isNotEmpty) Text('City: ${doctor.city}'),
                            Text('Qualification: ${doctor.qualification}'),
                            Text(
                              'Consultation Fee: Rs ${doctor.consultationFee.toStringAsFixed(0)}',
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 18, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(doctor.rating.toStringAsFixed(1)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.patientAppointmentForm,
                  arguments: DoctorArgs(
                    id: doctor.id,
                    name: doctor.name,
                    clinic: doctor.clinicName,
                    rating: doctor.rating,
                    age: doctor.age,
                    experience: doctor.yearsOfExperience,
                    address: 'Clinic: ${doctor.clinicName}',
                  ),
                ),
                child: const Text('Book Appointment'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showReportUserSheet(
                  context: context,
                  targetRole: 'DOCTOR',
                  targetDoctorId: doctor.id,
                  targetName: doctor.name,
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report Doctor'),
              ),
              const SizedBox(height: 20),
              Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FutureBuilder<List<Review>>(
                future: _reviewsFuture,
                builder: (context, reviewSnapshot) {
                  if (reviewSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (reviewSnapshot.hasError) {
                    return const Text('Failed to load reviews');
                  }

                  final reviews = reviewSnapshot.data ?? [];
                  if (reviews.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No reviews yet'),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 180,
                    child: PageView.builder(
                      itemCount: reviews.length,
                      itemBuilder: (context, index) {
                        final r = reviews[index];
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
                                        r.patientName,
                                        style: Theme.of(context).textTheme.titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.star,
                                      size: 18,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(r.rating.toStringAsFixed(1)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Text(
                                    r.reviewText,
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _openReviewSheet(doctor),
                child: const Text('Write a Review'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DoctorArgs {
  const DoctorArgs({
    required this.id,
    required this.name,
    required this.clinic,
    required this.rating,
    required this.age,
    required this.experience,
    required this.address,
  });

  final int id;
  final String name;
  final String clinic;
  final double rating;
  final int age;
  final int experience;
  final String address;
}
