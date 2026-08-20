import 'package:flutter/material.dart';

import '../../models/doctor_blog.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

class DoctorMyBlogsPage extends StatefulWidget {
  const DoctorMyBlogsPage({super.key});

  @override
  State<DoctorMyBlogsPage> createState() => _DoctorMyBlogsPageState();
}

class _DoctorMyBlogsPageState extends State<DoctorMyBlogsPage> {
  final ApiService _api = ApiService();
  late Future<List<DoctorBlog>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getMyDoctorBlogs();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getMyDoctorBlogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Blogs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.pushNamed(
            context,
            AppRoutes.doctorWriteBlog,
          );
          if (created == true && mounted) _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Blog'),
      ),
      body: FutureBuilder<List<DoctorBlog>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load blogs'));
          }
          final blogs = snapshot.data ?? [];
          if (blogs.isEmpty) {
            return const Center(child: Text('You have not posted any blogs yet.'));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: blogs.length,
              itemBuilder: (context, index) {
                final blog = blogs[index];
                return Card(
                  child: ListTile(
                    title: Text(blog.title),
                    subtitle: Text(
                      blog.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final updated = await Navigator.pushNamed(
                          context,
                          AppRoutes.doctorWriteBlog,
                          arguments: blog.id,
                        );
                        if (updated == true && mounted) _reload();
                      },
                    ),
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.doctorBlogDetail,
                      arguments: blog.id,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
