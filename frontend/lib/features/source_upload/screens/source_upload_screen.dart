// features/source_upload/screens/source_upload_screen.dart
// Purpose: Screen for attaching files and YouTube links to a workspace.
// Responsibilities: Interacts with file picker, shows lists of attached sources, allows deletion.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/source.dart';
import '../providers/source_providers.dart';
import '../../processing/services/processing_service.dart';
import '../../../core/router/app_router.dart';

class SourceUploadScreen extends ConsumerStatefulWidget {
  final String workspaceId;

  const SourceUploadScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<SourceUploadScreen> createState() => _SourceUploadScreenState();
}

class _SourceUploadScreenState extends ConsumerState<SourceUploadScreen> {
  bool _isUploading = false;

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Future<void> _pickAndUploadFile({
    required String label,
    required List<String> allowedExtensions,
  }) async {
    setState(() => _isUploading = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      final pickedFile = result.files.first;
      List<int> bytes;
      if (pickedFile.bytes != null) {
        bytes = pickedFile.bytes!;
      } else if (pickedFile.path != null) {
        bytes = await File(pickedFile.path!).readAsBytes();
      } else {
        throw Exception('Could not read picked file data');
      }

      await ref.read(sourcesProvider(widget.workspaceId).notifier).uploadFile(
            bytes,
            pickedFile.name,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${pickedFile.name}'),
            backgroundColor: context.colors.statusReady,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showYouTubeDialog() {
    showDialog(
      context: context,
      builder: (context) => _YouTubeUrlDialog(workspaceId: widget.workspaceId),
    );
  }

  void _showWebsiteDialog() {
    showDialog(
      context: context,
      builder: (context) => _WebsiteUrlDialog(workspaceId: widget.workspaceId),
    );
  }

  void _showCopyTextDialog() {
    showDialog(
      context: context,
      builder: (context) => _CopyTextDialog(workspaceId: widget.workspaceId),
    );
  }

  Future<void> _startProcessingPipeline() async {
    setState(() => _isUploading = true);
    try {
      await ref.read(processingServiceProvider).startProcessing(widget.workspaceId);
      if (mounted) {
        context.push(
          AppRoutes.processing.replaceAll(':workspaceId', widget.workspaceId),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start processing: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sourcesState = ref.watch(sourcesProvider(widget.workspaceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Sources'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: sourcesState.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: colors.statusFailed),
              const SizedBox(height: 16),
              Text('Failed to load sources', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(error.toString(), style: TextStyle(color: colors.textSecondary)),
            ],
          ),
        ),
        data: (sources) {
          final pdfCount = sources.where((s) => s.type == SourceType.pdf).length;
          final imageCount = sources.where((s) => s.type == SourceType.image).length;
          final audioCount = sources.where((s) => s.type == SourceType.audio).length;
          final youtubeCount = sources.where((s) => s.type == SourceType.youtube).length;
          final websiteCount = sources.where((s) => s.type == SourceType.website).length;
          final textCount = sources.where((s) => s.type == SourceType.text).length;

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Knowledge Sources',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 22,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Attach PDFs, images, audios, YouTube URLs, websites, or copied text.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13.5,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // --- Source Types Grid ---
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _SourceTypeCard(
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'PDF',
                          count: pdfCount,
                          onTap: () => _pickAndUploadFile(
                            label: 'PDF',
                            allowedExtensions: ['pdf'],
                          ),
                        ),
                        _SourceTypeCard(
                          icon: Icons.image_rounded,
                          label: 'Images',
                          count: imageCount,
                          onTap: () => _pickAndUploadFile(
                            label: 'Images',
                            allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                          ),
                        ),
                        _SourceTypeCard(
                          icon: Icons.mic_rounded,
                          label: 'Audio',
                          count: audioCount,
                          onTap: () => _pickAndUploadFile(
                            label: 'Audio',
                            allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'ogg'],
                          ),
                        ),
                        _SourceTypeCard(
                          icon: Icons.play_circle_rounded,
                          label: 'YouTube',
                          count: youtubeCount,
                          onTap: _showYouTubeDialog,
                        ),
                        _SourceTypeCard(
                          icon: Icons.language_rounded,
                          label: 'Website Link',
                          count: websiteCount,
                          onTap: _showWebsiteDialog,
                        ),
                        _SourceTypeCard(
                          icon: Icons.notes_rounded,
                          label: 'Copy Text',
                          count: textCount,
                          onTap: _showCopyTextDialog,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // --- Attached Sources List ---
                    Text(
                      'Attached Sources (${sources.length})',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: sources.isEmpty
                          ? Center(
                              child: Text(
                                'No sources attached yet.',
                                style: TextStyle(color: colors.textMuted, fontSize: 13.5),
                              ),
                            )
                          : ListView.separated(
                              itemCount: sources.length,
                              separatorBuilder: (context, index) => Divider(color: colors.divider, height: 1),
                              itemBuilder: (context, index) {
                                final source = sources[index];
                                IconData itemIcon;
                                switch (source.type) {
                                  case SourceType.pdf:
                                    itemIcon = Icons.picture_as_pdf_rounded;
                                    break;
                                  case SourceType.image:
                                    itemIcon = Icons.image_rounded;
                                    break;
                                  case SourceType.audio:
                                    itemIcon = Icons.mic_rounded;
                                    break;
                                  case SourceType.youtube:
                                    itemIcon = Icons.play_circle_rounded;
                                    break;
                                  case SourceType.website:
                                    itemIcon = Icons.language_rounded;
                                    break;
                                  case SourceType.text:
                                    itemIcon = Icons.notes_rounded;
                                    break;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(itemIcon, color: colors.primary, size: 18),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              source.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                if (source.sizeBytes != null) ...[
                                                  Text(
                                                    _formatSize(source.sizeBytes),
                                                    style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text('•', style: TextStyle(color: colors.textMuted, fontSize: 11.5)),
                                                  const SizedBox(width: 8),
                                                ],
                                                Text(
                                                  'Added ${_formatDate(source.addedAt)}',
                                                  style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.statusFailed),
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(sourcesProvider(widget.workspaceId).notifier)
                                                .deleteSource(source.id);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed to delete: ${e.toString()}'),
                                                  backgroundColor: colors.statusFailed,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 24),

                    // --- Start Processing Button ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: sources.isEmpty ? null : _startProcessingPipeline,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: colors.surfaceElevated,
                          disabledForegroundColor: colors.textMuted,
                        ),
                        child: const Text('Start Processing'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUploading)
                Container(
                  color: Colors.black.withAlpha(50),
                  child: const Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SourceTypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _SourceTypeCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: colors.textPrimary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: colors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 1 ? '1 item' : '$count items',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_rounded, size: 16, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _YouTubeUrlDialog extends ConsumerStatefulWidget {
  final String workspaceId;

  const _YouTubeUrlDialog({required this.workspaceId});

  @override
  ConsumerState<_YouTubeUrlDialog> createState() => _YouTubeUrlDialogState();
}

class _YouTubeUrlDialogState extends ConsumerState<_YouTubeUrlDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(sourcesProvider(widget.workspaceId).notifier).addYouTubeUrl(_controller.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add YouTube URL: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      title: Text(
        'Add YouTube Video',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a valid YouTube video URL to index.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'https://www.youtube.com/watch?v=...',
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'URL is required';
                }
                final url = val.trim();
                final hasMatch = RegExp(
                  r'(https?://)?(www\.)?(youtube|youtu|youtube-nocookie)\.(com|be)/(watch\?v=|embed/|v/|.+\?v=)?([^&=%\?]{11})'
                ).hasMatch(url);
                if (!hasMatch) {
                  return 'Please enter a valid YouTube video URL';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

class _WebsiteUrlDialog extends ConsumerStatefulWidget {
  final String workspaceId;

  const _WebsiteUrlDialog({required this.workspaceId});

  @override
  ConsumerState<_WebsiteUrlDialog> createState() => _WebsiteUrlDialogState();
}

class _WebsiteUrlDialogState extends ConsumerState<_WebsiteUrlDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(sourcesProvider(widget.workspaceId).notifier).addWebsiteUrl(_controller.text.trim());
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add Website URL: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      title: Text(
        'Add Website Link',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a website URL (starts with http:// or https://) to extract content.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'https://example.com/page',
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'URL is required';
                }
                final url = val.trim();
                if (!url.startsWith('http://') && !url.startsWith('https://')) {
                  return 'URL must start with http:// or https://';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

class _CopyTextDialog extends ConsumerStatefulWidget {
  final String workspaceId;

  const _CopyTextDialog({required this.workspaceId});

  @override
  ConsumerState<_CopyTextDialog> createState() => _CopyTextDialogState();
}

class _CopyTextDialogState extends ConsumerState<_CopyTextDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(sourcesProvider(widget.workspaceId).notifier).addCopiedText(
            _titleController.text.trim(),
            _contentController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save text: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      title: Text(
        'Paste Text',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a name for this source and paste your content below.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Source Name',
                  labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                  hintText: 'e.g. My Notes',
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLines: 8,
                minLines: 4,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Pasted Content',
                  labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                  hintText: 'Paste or type text here...',
                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.all(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Content is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
