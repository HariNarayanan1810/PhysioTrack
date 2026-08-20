import 'package:flutter/material.dart';

class DoctorManagePatientsPage extends StatelessWidget {
  const DoctorManagePatientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final patients = ['Aaravind', 'Sherill', 'Praveen', 'Ajay Saravanan'];

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Patients')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: patients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(patients[index]),
              subtitle: const Text('Active treatment'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}
