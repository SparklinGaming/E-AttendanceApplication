import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/current_user_provider.dart';
import '../../repositories/issue_repository.dart';

/// Employee issue report form for store-related concerns.
class IssueReportPage extends StatefulWidget {
  const IssueReportPage({super.key});

  @override
  State<IssueReportPage> createState() => _IssueReportPageState();
}

class _IssueReportPageState extends State<IssueReportPage> {
  final _formKey = GlobalKey<FormState>();
  final IssueRepository _repo = IssueRepository();
  final TextEditingController _descCtrl = TextEditingController();

  String _selectedCategory = 'Safety Hazard';
  File? _attachmentFile;
  bool _uploading = false;

  static const List<String> _categories = [
    'Safety Hazard',
    'Inventory / Stock Issue',
    'Facility / Equipment',
    'Customer Issue',
    'HR / Personnel',
    'Other',
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attachment'),
        content: const Text('Choose image source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 70,
    );
    if (picked != null && mounted) {
      setState(() => _attachmentFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final uid = context.read<CurrentUserProvider>().uid;
    if (uid == null) {
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Not logged in.')));
      return;
    }

    setState(() => _uploading = true);

    try {
      // Upload attachment first if any
      String? attachmentUrl;
      if (_attachmentFile != null) {
        attachmentUrl = await _repo.uploadAttachment(uid, _attachmentFile!);
      }

      final name = context.read<CurrentUserProvider>().displayName;

      await _repo.submitIssue(IssueReport(
        uid: uid,
        name: name == 'there' ? 'Employee' : name,
        category: _selectedCategory,
        description: _descCtrl.text.trim(),
        attachmentUrl: attachmentUrl,
      ));

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report submitted!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Issue')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedCategory = val!),
                decoration:
                    const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              const Text('Description',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Describe the issue in detail...',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty
                        ? 'Please describe the issue'
                        : null,
              ),
              const SizedBox(height: 20),

              // ── Attachment ────────────────────────────────────────
              const Text('Attachment (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.image),
                label: Text(
                  _attachmentFile != null
                      ? '${_attachmentFile!.path.split('/').last}'
                      : 'Add Photo',
                ),
              ),
              if (_attachmentFile != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _attachmentFile!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Report',
                          style: TextStyle(
                              color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
