import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../models/doctor_blog.dart';
import '../../services/api_service.dart';

class DoctorBlogDetailPage extends StatefulWidget {
  const DoctorBlogDetailPage({super.key});

  @override
  State<DoctorBlogDetailPage> createState() => _DoctorBlogDetailPageState();
}

class _DoctorBlogDetailPageState extends State<DoctorBlogDetailPage> {
  final ApiService _api = ApiService();
  Future<DoctorBlog>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final blogId = args is int ? args : int.tryParse('$args');
    if (blogId == null || blogId <= 0) {
      _future = Future.error('Invalid blog id');
    } else {
      _future = _api.getDoctorBlogById(blogId);
    }
  }

  QuillController _buildReadOnlyController(String rawContent) {
    try {
      final parsed = jsonDecode(rawContent);
      if (parsed is List) {
        final doc = Document.fromJson(parsed.cast<Map<String, dynamic>>());
        return QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      }
    } catch (_) {
      // fallback to plain text below
    }
    final doc = Document()..insert(0, rawContent);
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blog Detail')),
      body: FutureBuilder<DoctorBlog>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load blog'));
          }
          final blog = snapshot.data;
          if (blog == null) {
            return const Center(child: Text('Blog not found'));
          }

          final contentController = _buildReadOnlyController(blog.content);
          final imageUrl = _api.resolveFileUrl(blog.mediaUrl);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (blog.mediaUrl != null && blog.mediaUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 220,
                      color: Colors.blueGrey.shade50,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, size: 44),
                ),
              const SizedBox(height: 14),
              Text(
                blog.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (blog.doctorName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('By ${blog.doctorName}'),
              ],
              const SizedBox(height: 8),
              Text(
                blog.shortDescription,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              QuillEditor.basic(
                controller: contentController,
                config: const QuillEditorConfig(
                  scrollable: false,
                  showCursor: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
