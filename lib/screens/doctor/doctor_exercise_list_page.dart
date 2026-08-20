import 'package:flutter/material.dart';

import '../../models/exercise_library_item.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../widgets/exercise_media_view.dart';

class DoctorExerciseListPage extends StatefulWidget {
  const DoctorExerciseListPage({super.key});

  @override
  State<DoctorExerciseListPage> createState() => _DoctorExerciseListPageState();
}

class _DoctorExerciseListPageState extends State<DoctorExerciseListPage> {
  final ApiService _api = ApiService();
  late Future<List<ExerciseLibraryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getExerciseLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Library')),
      body: FutureBuilder<List<ExerciseLibraryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load exercise library'));
          }
          final exercises = snapshot.data ?? [];
          if (exercises.isEmpty) {
            return const Center(child: Text('No exercises in library'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = exercises[index];
              final title = item.name.trim().isEmpty
                  ? 'Exercise ${item.id}'
                  : item.name.trim();
              final description = item.description.trim().isEmpty
                  ? 'No description'
                  : item.description.trim();
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.doctorExerciseDetail,
                    arguments: item,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 74,
                            height: 74,
                            child: ExerciseMediaView(
                              mediaUrl: _api.resolveFileUrl(item.demoMediaUrl),
                              width: 74,
                              height: 74,
                              borderRadius: 10,
                              compact: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
