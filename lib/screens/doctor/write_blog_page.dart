import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../services/api_service.dart';

class WriteBlogPage extends StatefulWidget {
  const WriteBlogPage({super.key});

  @override
  State<WriteBlogPage> createState() => _WriteBlogPageState();
}

class _WriteBlogPageState extends State<WriteBlogPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final QuillController _quillController = QuillController.basic();
  final ApiService _api = ApiService();

  bool _submitting = false;
  bool _uploadingImage = false;
  String _uploadedMediaUrl = '';
  String _uploadedFileName = '';
  int? _editingBlogId;
  bool _loadingExisting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_editingBlogId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final blogId = args is int ? args : int.tryParse('$args');
    if (blogId != null && blogId > 0) {
      _editingBlogId = blogId;
      _loadBlogForEdit(blogId);
    }
  }

  Future<void> _loadBlogForEdit(int blogId) async {
    setState(() => _loadingExisting = true);
    try {
      final blog = await _api.getDoctorBlogById(blogId);
      _titleCtrl.text = blog.title;
      _shortDescCtrl.text = blog.shortDescription;
      _uploadedMediaUrl = blog.mediaUrl ?? '';
      _uploadedFileName = _uploadedMediaUrl.isEmpty ? '' : 'Uploaded image';
      try {
        final parsed = jsonDecode(blog.content);
        if (parsed is List) {
          _quillController.document = Document.fromJson(
            parsed.cast<Map<String, dynamic>>(),
          );
        } else {
          _quillController.document = Document()..insert(0, blog.content);
        }
      } catch (_) {
        _quillController.document = Document()..insert(0, blog.content);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load blog for editing')),
      );
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _shortDescCtrl.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _uploadingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Invalid image data');
      }
      final uploaded = await _api.uploadDoctorBlogImageBytes(
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() {
        _uploadedMediaUrl = uploaded;
        _uploadedFileName = file.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image')),
      );
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final delta = _quillController.document.toDelta().toJson();
    final encodedContent = jsonEncode(delta);
    final plainText = _quillController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_editingBlogId == null) {
        await _api.createDoctorBlog(
          title: _titleCtrl.text.trim(),
          shortDescription: _shortDescCtrl.text.trim(),
          content: encodedContent,
          mediaUrl: _uploadedMediaUrl,
        );
      } else {
        await _api.updateDoctorBlog(
          blogId: _editingBlogId!,
          title: _titleCtrl.text.trim(),
          shortDescription: _shortDescCtrl.text.trim(),
          content: encodedContent,
          mediaUrl: _uploadedMediaUrl,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingBlogId == null
                ? 'Blog published successfully'
                : 'Blog updated successfully',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to publish blog')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = _api.resolveFileUrl(_uploadedMediaUrl);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingBlogId == null ? 'Write Blog' : 'Edit Blog'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingExisting)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Title is required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shortDescCtrl,
              decoration: const InputDecoration(labelText: 'Short Description'),
              maxLines: 2,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Short description is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickAndUploadImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_uploadingImage ? 'Uploading...' : 'Upload Image'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _uploadedFileName.isEmpty
                        ? 'No image selected'
                        : _uploadedFileName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_uploadedMediaUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  previewUrl,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 160,
                    color: Colors.blueGrey.shade50,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            QuillSimpleToolbar(
              controller: _quillController,
              config: const QuillSimpleToolbarConfig(
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showListBullets: true,
                showListNumbers: true,
                showHeaderStyle: true,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 320,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: QuillEditor.basic(
                controller: _quillController,
                config: const QuillEditorConfig(
                  placeholder: 'Write your blog content...',
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _submitting || _loadingExisting ? null : _publish,
              child: Text(
                _submitting
                    ? (_editingBlogId == null ? 'Publishing...' : 'Updating...')
                    : (_editingBlogId == null ? 'Publish' : 'Update'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
