import 'package:flutter/material.dart';

import '../../models/discussion.dart';
import '../../models/doctor_blog.dart';
import '../../models/session_user.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final ApiService _api = ApiService();

  SessionUser? _session;
  String _doctorName = 'Doctor';
  String _doctorEmail = '';
  String _verificationStatus = 'not_applied';

  bool _loading = true;
  String? _error;

  int _todaysAppointmentsCount = 0;
  int _todaysHomeVisitsCount = 0;
  double _monthlyEarnings = 0;
  List<Map<String, dynamic>> _todaySchedule = [];
  List<DoctorBlog> _recentBlogs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await SessionService().getSession();
      if (!mounted) return;
      if (session != null) {
        _session = session;
        _doctorName = session.name.isEmpty ? 'Doctor' : session.name;
        _doctorEmail = session.email;
      }

      final results = await Future.wait([
        _api.getDoctorDashboardSummary(),
        _api.getDoctorTodaySchedule(),
        _api.getDoctorBlogFeed(limit: 3),
      ]);
      if (!mounted) return;

      final summary = results[0] as Map<String, dynamic>;
      final schedule = results[1] as List<Map<String, dynamic>>;
      final blogs = results[2] as List<DoctorBlog>;

      _todaysAppointmentsCount = _toInt(summary['todaysAppointmentsCount']);
      _todaysHomeVisitsCount = _toInt(summary['todaysHomeVisitsCount']);
      _monthlyEarnings = _toDouble(summary['monthlyEarnings']);
      _verificationStatus = (summary['verificationStatus'] ?? 'not_applied')
          .toString()
          .toLowerCase();
      final emailFromSummary = (summary['email'] ?? '').toString();
      if (emailFromSummary.isNotEmpty) {
        _doctorEmail = emailFromSummary;
      }
      _todaySchedule = schedule;
      _recentBlogs = blogs;

      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load dashboard';
      });
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _verificationText() {
    switch (_verificationStatus) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Not Applied';
    }
  }

  Color _verificationColor() {
    switch (_verificationStatus) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _openScheduleDetail(Map<String, dynamic> item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final visitType = (item['visit_type'] ?? '').toString().toUpperCase();
        return AlertDialog(
          title: const Text('Appointment Detail'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${(item['patient_name'] ?? '').toString()}'),
              Text('Time: ${(item['appointment_time'] ?? '').toString()}'),
              Text('Type: ${visitType == 'HOME' ? 'Home' : 'Clinic'}'),
              Text('Status: ${(item['status'] ?? '').toString()}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1B5E7A)),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Doctor Menu',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('View Appointments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.doctorAppointments);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('My Patients'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.doctorMyPatients);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center_outlined),
              title: const Text('Exercise Library'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.doctorExerciseList);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Payments'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.doctorPayments);
              },
            ),
            ListTile(
              leading: const Icon(Icons.currency_rupee_outlined),
              title: const Text('Fee Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.doctorFeeSettings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: const Text('Today\'s Home Visits'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.doctorHomeVisitToday);
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
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Write Blog'),
              onTap: () async {
                Navigator.pop(context);
                final created = await Navigator.pushNamed(
                  context,
                  AppRoutes.doctorWriteBlog,
                );
                if (created == true && mounted) {
                  _loadDashboard();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('My Blogs'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.doctorMyBlogs);
              },
            ),
            if (_verificationStatus != 'approved')
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Apply for Verification'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    AppRoutes.doctorVerificationForm,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(title: const Text('Doctor Dashboard')),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(_error!)),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            child: Icon(Icons.medical_services_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _doctorName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _doctorEmail.isEmpty
                                      ? (_session?.email ?? '')
                                      : _doctorEmail,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _verificationColor().withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _verificationText(),
                              style: TextStyle(color: _verificationColor()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Today\'s Appointments',
                          value: '$_todaysAppointmentsCount',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Today\'s Home Visits',
                          value: '$_todaysHomeVisitsCount',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Earnings Summary',
                          value: 'Rs ${_monthlyEarnings.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s Schedule',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          if (_todaySchedule.isEmpty)
                            const Text('No appointments scheduled for today.')
                          else
                            ..._todaySchedule.map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  (item['patient_name'] ?? '').toString(),
                                ),
                                subtitle: Text(
                                  ((item['visit_type'] ?? '')
                                              .toString()
                                              .toUpperCase() ==
                                          'HOME')
                                      ? 'Home'
                                      : 'Clinic',
                                ),
                                leading: Text(
                                  (item['appointment_time'] ?? '').toString(),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openScheduleDetail(item),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _DoctorDiscussionSection(),
                  const SizedBox(height: 16),
                  Card(
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
                          if (_recentBlogs.isEmpty)
                            const Text('You haven\'t published any blog yet.')
                          else
                            ..._recentBlogs.map(
                              (blog) => Card(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 84,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            color: Colors.blueGrey.shade50,
                                            image:
                                                (blog.mediaUrl != null &&
                                                    blog.mediaUrl!.isNotEmpty)
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      _api.resolveFileUrl(
                                                        blog.mediaUrl,
                                                      ),
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child:
                                              (blog.mediaUrl == null ||
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
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleSmall,
                                              ),
                                              if (blog.doctorName.isNotEmpty)
                                                Text(
                                                  'By ${blog.doctorName}',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.all(14),
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

class _DoctorDiscussionSection extends StatefulWidget {
  const _DoctorDiscussionSection();

  @override
  State<_DoctorDiscussionSection> createState() =>
      _DoctorDiscussionSectionState();
}

class _DoctorDiscussionSectionState extends State<_DoctorDiscussionSection> {
  final ApiService _api = ApiService();
  final TextEditingController _answerCtrl = TextEditingController();
  late Future<List<DiscussionQuestion>> _future;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _api.getDiscussions();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.getDiscussions();
      _pageIndex = 0;
    });
  }

  Future<void> _answerQuestion(DiscussionQuestion question) async {
    _answerCtrl.clear();
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
                'Answer for ${question.patientName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(question.questionText),
              const SizedBox(height: 12),
              TextField(
                controller: _answerCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Your answer'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final text = _answerCtrl.text.trim();
                  if (text.isEmpty) return;
                  try {
                    await _api.createDiscussionAnswer(
                      questionId: question.id,
                      answerText: text,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _reload();
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to submit answer')),
                    );
                  }
                },
                child: const Text('Submit Answer'),
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
            Text('Discussions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            FutureBuilder<List<DiscussionQuestion>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Text('Failed to load discussions');
                }
                final questions = snapshot.data ?? [];
                if (questions.isEmpty) {
                  return const Text('No patient questions yet.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                        itemCount: questions.length,
                        onPageChanged: (index) {
                          setState(() => _pageIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final q = questions[index];
                          return Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.patientName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    q.questionText,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: q.answers.isEmpty
                                        ? const Text('No answers yet')
                                        : ListView(
                                            padding: EdgeInsets.zero,
                                            children: q.answers
                                                .map(
                                                  (a) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 4,
                                                        ),
                                                    child: Text(
                                                      'Dr. ${a.doctorName}: ${a.answerText}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => _answerQuestion(q),
                                      child: const Text('Answer'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_pageIndex + 1} / ${questions.length}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
