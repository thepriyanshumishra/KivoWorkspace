// features/workspace/screens/workspace_screen.dart
// Purpose: Workspace screen showing the sources left panel and chat right panel.
// Responsibilities: Renders active workspace details and attached sources.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../providers/workspace_providers.dart';
import '../../source_upload/models/source.dart' as src_model;
import '../../source_upload/providers/source_providers.dart';

class WorkspaceScreen extends ConsumerWidget {
  final String workspaceId;

  const WorkspaceScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final activeWorkspaceState = ref.watch(activeWorkspaceProvider(workspaceId));
    final sourcesState = ref.watch(sourcesProvider(workspaceId));

    final String appBarTitle = activeWorkspaceState.when(
      data: (workspace) => workspace.name,
      loading: () => 'Loading...',
      error: (_, __) => 'Workspace',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Row(
        children: [
          // --- Left Panel: Sources ---
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: colors.sidebarBackground,
              border: Border(
                right: BorderSide(color: colors.divider, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Sources',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        tooltip: 'Add Sources',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          context.push(
                            AppRoutes.sourceUpload.replaceAll(':workspaceId', workspaceId),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: sourcesState.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                    error: (_, __) => _buildEmptyState(context),
                    data: (sources) {
                      if (sources.isEmpty) {
                        return _buildEmptyState(context);
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: sources.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final source = sources[index];
                          IconData sourceIcon;
                          switch (source.type) {
                            case src_model.SourceType.pdf:
                              sourceIcon = Icons.picture_as_pdf_rounded;
                              break;
                            case src_model.SourceType.image:
                              sourceIcon = Icons.image_rounded;
                              break;
                            case src_model.SourceType.audio:
                              sourceIcon = Icons.mic_rounded;
                              break;
                            case src_model.SourceType.youtube:
                              sourceIcon = Icons.play_circle_rounded;
                              break;
                            case src_model.SourceType.website:
                              sourceIcon = Icons.language_rounded;
                              break;
                            case src_model.SourceType.text:
                              sourceIcon = Icons.notes_rounded;
                              break;
                          }

                          // Map status colors dynamically
                          Color statusColor;
                          Color statusBg;
                          String statusText;

                          switch (source.status) {
                            case src_model.SourceStatus.processing:
                              statusColor = colors.statusProcessing;
                              statusBg = colors.statusProcessingBg;
                              statusText = 'Processing';
                              break;
                            case src_model.SourceStatus.ready:
                              statusColor = colors.statusReady;
                              statusBg = colors.statusReadyBg;
                              statusText = 'Ready';
                              break;
                            case src_model.SourceStatus.failed:
                              statusColor = colors.statusFailed;
                              statusBg = colors.statusFailedBg;
                              statusText = 'Failed';
                              break;
                            case src_model.SourceStatus.pending:
                              statusColor = colors.textSecondary;
                              statusBg = colors.border;
                              statusText = 'Pending';
                              break;
                          }

                          return Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: colors.border),
                            ),
                            color: colors.surface,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _showSourceDetailsDialog(context, source),
                              hoverColor: colors.primarySubtle.withAlpha(100),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(sourceIcon, color: colors.primary, size: 16),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        source.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // --- Right Panel: Chat ---
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 40,
                          color: colors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chat with your documents will appear here.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Chat Input Placeholder ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: colors.divider, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            hintText: 'Ask your workspace a question...',
                            hintStyle: TextStyle(
                                color: colors.textMuted, fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                  color: colors.border),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                  color: colors.border),
                            ),
                            filled: true,
                            fillColor: colors.surfaceElevated,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: null,
                        icon: const Icon(Icons.send_rounded),
                        color: colors.primary,
                        disabledColor: colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No sources added yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              context.push(
                AppRoutes.sourceUpload.replaceAll(':workspaceId', workspaceId),
              );
            },
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add Sources', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showSourceDetailsDialog(BuildContext context, src_model.Source source) {
    showDialog(
      context: context,
      builder: (context) => _SourceDetailsDialog(source: source),
    );
  }
}

class _SourceDetailsDialog extends StatelessWidget {
  final src_model.Source source;

  const _SourceDetailsDialog({required this.source});

  String _formatSize(int? bytes) {
    if (bytes == null) return 'N/A';
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

  String _formatDuration(dynamic durationSec) {
    if (durationSec == null) return '0:00';
    final double secDouble = (durationSec is num) ? durationSec.toDouble() : double.tryParse(durationSec.toString()) ?? 0.0;
    final int totalSec = secDouble.round();
    final int hours = totalSec ~/ 3600;
    final int minutes = (totalSec % 3600) ~/ 60;
    final int seconds = totalSec % 60;
    
    final String minStr = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final String secStr = seconds.toString().padLeft(2, '0');
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$secStr';
    } else {
      return '$minStr:$secStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    String fileTypeLabel = 'File Document';
    switch (source.type) {
      case src_model.SourceType.pdf:
        fileTypeLabel = 'PDF Document';
        break;
      case src_model.SourceType.image:
        fileTypeLabel = 'Image File';
        break;
      case src_model.SourceType.audio:
        fileTypeLabel = 'Audio Recording';
        break;
      case src_model.SourceType.youtube:
        fileTypeLabel = 'YouTube Video Link';
        break;
      case src_model.SourceType.website:
        fileTypeLabel = 'Website Page';
        break;
      case src_model.SourceType.text:
        fileTypeLabel = 'Pasted Text';
        break;
    }

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
      title: Row(
        children: [
          Expanded(
            child: Text(
              source.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // --- Metadata Grid ---
            Table(
              columnWidths: const {
                0: FixedColumnWidth(100),
                1: FlexColumnWidth(),
              },
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('Type', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(fileTypeLabel, style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('File Size', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_formatSize(source.sizeBytes), style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('Added On', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_formatDate(source.addedAt), style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('Status', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(source.status.name.toUpperCase(), style: TextStyle(
                        color: source.status == src_model.SourceStatus.ready ? colors.statusReady : colors.statusProcessing,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // --- Stats Row (if processed and stats are present) ---
            if (source.status == src_model.SourceStatus.ready && source.stats != null) ...[
              Text(
                'Extraction Stats',
                style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (source.stats?['pages'] != null) ...[
                    Expanded(
                      child: _buildStatCard(context, 'Pages', source.stats!['pages'].toString()),
                    ),
                    const SizedBox(width: 8),
                  ] else if (source.stats?['width'] != null && source.stats?['height'] != null) ...[
                    Expanded(
                      child: _buildStatCard(context, 'Dimensions', '${source.stats!['width']}×${source.stats!['height']}'),
                    ),
                    const SizedBox(width: 8),
                  ] else if (source.stats?['duration'] != null) ...[
                    Expanded(
                      child: _buildStatCard(context, 'Duration', _formatDuration(source.stats!['duration'])),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: _buildStatCard(context, 'Words', source.stats!['words'].toString()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(context, 'Chunks', source.stats!['chunks'].toString()),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            // --- Summary Box (if processed and summary is present) ---
            if (source.status == src_model.SourceStatus.ready && source.summary != null) ...[
              Text(
                'Summary Preview',
                style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.sidebarBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      source.summary!,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (source.status == src_model.SourceStatus.ready && source.summary == null) ...[
              Text(
                'Summary Preview',
                style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.sidebarBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'No text extracted from this source.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.sidebarBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'Processing details will be available once ingestion is complete.',
                  style: TextStyle(color: colors.textMuted, fontSize: 12.5, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: colors.sidebarBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: colors.textMuted, fontSize: 10.5)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
