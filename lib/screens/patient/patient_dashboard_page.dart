import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/appointment.dart';
import '../../models/discussion.dart';
import '../../models/doctor.dart';
import '../../models/doctor_blog.dart';
import '../../models/patient.dart';
import '../../models/session_user.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import 'patient_doctor_detail_page.dart';

class PatientDashboardPage extends StatefulWidget {
  const PatientDashboardPage({super.key});

  @override
  State<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends State<PatientDashboardPage> {
  static const Map<String, List<String>> _districtsByState = {
    'Tamil Nadu': [
      'Coimbatore',
      'Chennai',
      'Madurai',
      'Salem',
      'Trichy',
      'Tirunelveli',
    ],
    'Kerala': [
      'Kochi',
      'Thiruvananthapuram',
      'Kozhikode',
      'Thrissur',
      'Kannur',
      'Kollam',
    ],
    'Karnataka': [
      'Bengaluru',
      'Mysuru',
      'Mangaluru',
      'Hubballi',
      'Belagavi',
      'Davanagere',
    ],
    'Andhra Pradesh': [
      'Visakhapatnam',
      'Vijayawada',
      'Guntur',
      'Nellore',
      'Kurnool',
      'Tirupati',
    ],
  };

  final ApiService _api = ApiService();
  final _searchCtrl = TextEditingController();

  SessionUser? _session;
  String _patientName = 'Patient';
  int? _patientId;
  String _locationLabel = 'Doctors near your current location';
  String _selectedState = 'Tamil Nadu';
  String _selectedDistrict = 'Coimbatore';
  String _patientCity = '';
  double? _patientLatitude;
  double? _patientLongitude;
  double? _currentLatitude;
  double? _currentLongitude;
  bool _useCurrentLocationFilter = false;
  bool _hasManualCitySelection = false;
  late Future<List<Doctor>> _approvedDoctorsFuture;
  late Future<List<DoctorBlog>> _blogFeedFuture;

  @override
  void initState() {
    super.initState();
    _approvedDoctorsFuture = _api.getApprovedDoctors();
    _blogFeedFuture = _api.getDoctorBlogFeed(limit: 3);
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await SessionService().getSession();
    if (!mounted || session == null) return;

    try {
      final user = await _api.getUserById(session.userId);
      Patient? profile;
      try {
        profile = await _api.getPatientProfile();
      } catch (_) {
        profile = null;
      }
      if (!mounted) return;
      setState(() {
        _session = user;
        _patientName = user.name.isEmpty ? 'Patient' : user.name;
        _patientId = user.patientId;
        _patientCity = (profile?.city ?? '').trim();
        _patientLatitude = profile?.latitude;
        _patientLongitude = profile?.longitude;
        _locationLabel = _patientCity.isNotEmpty
            ? 'Recommended doctors in $_patientCity'
            : 'Doctors near your current location';
        if (_patientCity.isNotEmpty) {
          _selectedDistrict = _patientCity;
        }
      });
    } catch (_) {
      setState(() {
        _session = session;
        _patientName = session.name.isEmpty ? 'Patient' : session.name;
        _patientId = session.patientId;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation(BuildContext sheetContext) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable location service to use current location')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
        _useCurrentLocationFilter = true;
        _hasManualCitySelection = false;
        _selectedDistrict = '';
        _locationLabel = 'Doctors within 3 km of your current location';
      });
      Navigator.pop(sheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Showing doctors within 3 km of your current location'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to fetch current location. Check GPS/location permission.',
          ),
        ),
      );
    }
  }

  void _openLocationSheet() {
    final states = _districtsByState.keys.toList();
    var selectedState =
        states.contains(_selectedState) ? _selectedState : states[0];
    var availableDistricts = _districtsByState[selectedState]!;
    var selectedDistrict = availableDistricts.contains(_selectedDistrict)
        ? _selectedDistrict
        : availableDistricts[0];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select Location',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedState,
                    items: states
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setSheetState(() {
                      selectedState = v ?? states[0];
                      availableDistricts = _districtsByState[selectedState]!;
                      selectedDistrict = availableDistricts[0];
                    }),
                    decoration: const InputDecoration(labelText: 'State'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDistrict,
                    items: availableDistricts
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setSheetState(
                      () => selectedDistrict = v ?? availableDistricts[0],
                    ),
                    decoration: const InputDecoration(labelText: 'District'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _useCurrentLocation(sheetContext),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use current location'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _selectedState = selectedState;
                        _selectedDistrict = selectedDistrict;
                        _useCurrentLocationFilter = false;
                        _hasManualCitySelection = true;
                        _locationLabel = 'Recommended doctors in $_selectedDistrict';
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Doctor> _filteredDoctors(List<Doctor> list) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (d) =>
              d.name.toLowerCase().contains(q) ||
              d.clinicName.toLowerCase().contains(q),
        )
        .toList();
  }

  List<Doctor> _recommendedDoctors(List<Doctor> list) {
    if (_useCurrentLocationFilter &&
        _currentLatitude != null &&
        _currentLongitude != null) {
      return list.where((doctor) {
        final distanceInMeters = Geolocator.distanceBetween(
          _currentLatitude!,
          _currentLongitude!,
          doctor.latitude,
          doctor.longitude,
        );
        return distanceInMeters <= 3000;
      }).toList();
    }

    if (_useCurrentLocationFilter) {
      return [];
    }

    final targetCity = _hasManualCitySelection
        ? _selectedDistrict.trim()
        : _patientCity.trim();
    if (targetCity.isEmpty) {
      return list;
    }

    final cityMatched = list
        .where(
          (doctor) => doctor.city.trim().toLowerCase() == targetCity.toLowerCase(),
        )
        .toList();
    return cityMatched;
  }

  @override
  Widget build(BuildContext context) {
    final showHomeView = _searchCtrl.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1B5E7A)),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Patient Menu',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.patientEditProfile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center_outlined),
              title: const Text('View Exercises'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.patientExerciseList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Appointment History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.patientAppointmentHistory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Payment History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.patientPayments);
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_information_outlined),
              title: const Text('My Treatment Plan'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.patientTreatmentPlan);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run_outlined),
              title: const Text('Daily Exercise'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.patientDailyExercise);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.notifications);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('My Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.myReports);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await AuthService().logout();
                if (!context.mounted) return;
                Navigator.popUntil(context, (r) => r.isFirst);
              },
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            name: _patientName,
            subtitle: _session?.email ?? 'Patient',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search clinic or doctor',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _openLocationSheet,
                icon: const Icon(Icons.place_outlined),
                tooltip: 'Select location',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_locationLabel, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FutureBuilder<List<Doctor>>(
            future: _approvedDoctorsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text('Failed to load doctors');
              }
              final all = snapshot.data ?? [];
              final filtered = _filteredDoctors(all);
              final recommended = _recommendedDoctors(all);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHomeView) ...[
                    Text(
                      'Recommended Doctors',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (recommended.isEmpty)
                      Text(
                        _useCurrentLocationFilter
                            ? 'No doctors found within 3 km of your current location.'
                            : 'No doctors found for the selected city.',
                      )
                    else
                      ...recommended.take(6).map((d) => _DoctorCard(doctor: d)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.patientDoctorList),
                      child: const Text('See More'),
                    ),
                    const SizedBox(height: 16),
                    _PatientBlogSection(blogFeedFuture: _blogFeedFuture),
                    const SizedBox(height: 16),
                    const _PatientDiscussionSection(),
                    const SizedBox(height: 16),
                    _AppointmentsSection(patientId: _patientId),
                    const SizedBox(height: 20),
                  ] else ...[
                    Text(
                      'Search Results',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const Text('No doctors found.')
                    else
                      ...filtered.map((d) => _DoctorCard(doctor: d)),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  final String name;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 26, child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey(doctor.id),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: doctor.profileImageUrl.isNotEmpty
              ? NetworkImage(doctor.profileImageUrl)
              : null,
          child: doctor.profileImageUrl.isEmpty
              ? const Icon(Icons.medical_services_outlined)
              : null,
        ),
        title: Text(doctor.name),
        subtitle: Text('${doctor.clinicName} - ${doctor.qualification}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 18, color: Colors.amber),
            const SizedBox(width: 4),
            Text(doctor.rating.toStringAsFixed(1)),
          ],
        ),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.patientDoctorDetail,
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
      ),
    );
  }
}

class _PatientDiscussionSection extends StatefulWidget {
  const _PatientDiscussionSection();

  @override
  State<_PatientDiscussionSection> createState() => _PatientDiscussionSectionState();
}

class _PatientDiscussionSectionState extends State<_PatientDiscussionSection> {
  final ApiService _api = ApiService();
  final TextEditingController _questionCtrl = TextEditingController();
  late Future<List<DiscussionQuestion>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getDiscussions();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.getDiscussions();
    });
  }

  Future<void> _askQuestion() async {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ask your question',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _questionCtrl,
                decoration: const InputDecoration(labelText: 'Type your question'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final text = _questionCtrl.text.trim();
                  if (text.isEmpty) return;
                  try {
                    await _api.createDiscussionQuestion(text);
                    _questionCtrl.clear();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _reload();
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to post question')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Discussion', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FutureBuilder<List<DiscussionQuestion>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const SizedBox(height: 120, child: Center(child: Text('Failed to load discussions')));
                }
                final questions = snapshot.data ?? [];
                if (questions.isEmpty) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: Text('No discussions yet')),
                  );
                }
                return SizedBox(
                  height: 170,
                  child: PageView.builder(
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final item = questions[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.patientName, style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 6),
                              Text(item.questionText, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              if (item.answers.isEmpty)
                                const Text('No doctor answers yet')
                              else
                                Text(
                                  'Dr. ${item.answers.last.doctorName}: ${item.answers.last.answerText}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
            FilledButton(
              onPressed: _askQuestion,
              child: const Text('Feel Free to Ask'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientBlogSection extends StatelessWidget {
  const _PatientBlogSection({required this.blogFeedFuture});

  final Future<List<DoctorBlog>> blogFeedFuture;

  @override
  Widget build(BuildContext context) {
    final api = ApiService();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest Blog Releases',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<DoctorBlog>>(
              future: blogFeedFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Text('Failed to load blogs');
                }

                final blogs = snapshot.data ?? [];
                if (blogs.isEmpty) {
                  return const Text('No blog posts available yet.');
                }

                return Column(
                  children: blogs
                      .map(
                        (blog) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            elevation: 0,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.doctorBlogDetail,
                                arguments: blog.id,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 84,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.blueGrey.shade50,
                                        image: (blog.mediaUrl != null &&
                                                blog.mediaUrl!.isNotEmpty)
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  api.resolveFileUrl(blog.mediaUrl),
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: (blog.mediaUrl == null ||
                                              blog.mediaUrl!.isEmpty)
                                          ? const Icon(Icons.image_outlined)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            blog.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          if (blog.doctorName.isNotEmpty)
                                            Text(
                                              'By ${blog.doctorName}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            blog.shortDescription,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsSection extends StatefulWidget {
  const _AppointmentsSection({required this.patientId});

  final int? patientId;

  @override
  State<_AppointmentsSection> createState() => _AppointmentsSectionState();
}

class _AppointmentsSectionState extends State<_AppointmentsSection> {
  final ApiService _api = ApiService();
  List<Appointment> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AppointmentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      _loading = true;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.patientId == null) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }

    try {
      final data = await _api.getAppointments(patientId: widget.patientId);
      final visible = data
          .where(
            (appointment) => !{
              'CANCELLED',
              'REJECTED',
            }.contains(appointment.status.toUpperCase()),
          )
          .toList();
      setState(() {
        _items = visible;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load appointments';
        _loading = false;
      });
    }
  }

  Future<void> _cancel(Appointment appt) async {
    try {
      await _api.cancelAppointment(appointmentId: appt.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((item) => item.id != appt.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('My Appointments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(_error!)
            else if (_items.isEmpty)
              const Text('No appointments yet')
            else
              ..._items.map(
                (appt) => Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(appt.doctorName),
                              const SizedBox(height: 4),
                              Text(
                                '${appt.appointmentDate} - ${appt.appointmentTime} - '
                                '${appt.visitType == 'HOME' ? 'Home' : 'Clinic'}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(appt.status),
                            if (appt.status.toUpperCase() != 'COMPLETED')
                              TextButton(
                                onPressed: () => _cancel(appt),
                                child: const Text('Cancel'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
