import 'package:flutter/material.dart';

class DoctorExerciseAssignmentPage extends StatelessWidget {
  const DoctorExerciseAssignmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final exercises = [
      'Ankle Pumps',
      'Shoulder Rolls',
      'Neck Stretch',
      'Hamstring Stretch',
      'Bridging',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Exercises')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: exercises.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final name = exercises[index];
          return Card(
            child: ListTile(
              title: Text(name),
              subtitle: const Text('Difficulty: Easy'),
              trailing: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Assigned: $name')));
                },
                child: const Text('Assign'),
              ),
            ),
          );
        },
      ),
    );
  }
}
