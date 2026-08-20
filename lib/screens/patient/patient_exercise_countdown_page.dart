import 'dart:async';

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

class PatientExerciseCountdownPage extends StatefulWidget {
  const PatientExerciseCountdownPage({super.key});

  @override
  State<PatientExerciseCountdownPage> createState() =>
      _PatientExerciseCountdownPageState();
}

class _PatientExerciseCountdownPageState
    extends State<PatientExerciseCountdownPage> {
  int _seconds = 10;
  Timer? _timer;
  Object? _sessionArgs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionArgs ??= ModalRoute.of(context)?.settings.arguments;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.patientExerciseSession,
          arguments: _sessionArgs,
        );
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Get Ready',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              '$_seconds',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
