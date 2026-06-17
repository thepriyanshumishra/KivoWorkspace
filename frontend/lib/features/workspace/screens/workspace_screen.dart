// features/workspace/screens/workspace_screen.dart
// Purpose: Workspace screen showing the sources left panel and chat right panel.
// Responsibilities: Renders active workspace details, attached sources, and embeds the interactive chat area on the right.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/font_provider.dart';
import '../../../core/router/app_router.dart';
import '../providers/workspace_providers.dart';
import '../../source_upload/models/source.dart' as src_model;
import '../../source_upload/providers/source_providers.dart';
import '../../chat/models/chat_message.dart';
import '../../chat/models/citation.dart';
import '../../chat/providers/chat_providers.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  final String workspaceId;

  const WorkspaceScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isSourcesPanelCollapsed = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    ref.read(chatProvider(widget.workspaceId).notifier).sendMessage(text);
    _focusNode.requestFocus();
    _scrollToBottom();
  }

  void _showClearChatConfirmation(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation?'),
        content: const Text('This will delete all messages in the current chat history locally.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(chatProvider(widget.workspaceId).notifier).clearChat();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.statusFailed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showWorkspaceSettingsDialog(BuildContext context) {
    final colors = context.colors;
    final activeWorkspaceState = ref.read(activeWorkspaceProvider(widget.workspaceId));
    final workspace = activeWorkspaceState.value;
    if (workspace == null) return;

    final TextEditingController nameController = TextEditingController(text: workspace.name);
    final TextEditingController instructionsController = TextEditingController(text: workspace.instructions);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          surfaceTintColor: Colors.transparent,
          backgroundColor: colors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border),
          ),
          title: Row(
            children: [
              Icon(Icons.settings_outlined, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Workspace Settings',
                style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workspace Name',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter workspace name...',
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    filled: true,
                    fillColor: colors.background,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Custom System Instructions',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: instructionsController,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'e.g., Answer in Hindi, use bullet points, explain simply, focus on coding patterns...',
                    hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    filled: true,
                    fillColor: colors.background,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These instructions customize response behavior, format, or language dynamically.',
                  style: TextStyle(color: colors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newInstructions = instructionsController.text.trim();
                
                if (newName.isEmpty) return;

                try {
                  await ref.read(workspacesProvider.notifier).updateWorkspaceSettings(
                    widget.workspaceId,
                    name: newName,
                    instructions: newInstructions,
                  );
                  
                  ref.invalidate(activeWorkspaceProvider(widget.workspaceId));
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Workspace settings updated successfully.'),
                        backgroundColor: colors.statusReady,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update workspace settings: $e'),
                        backgroundColor: colors.statusFailed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    final colors = context.colors;

    final List<Map<String, dynamic>> actions = [
      {
        'label': 'Summarize',
        'icon': Icons.summarize_outlined,
        'query': 'Summarize the references across this workspace.',
      },
      {
        'label': 'Create Notes',
        'icon': Icons.note_alt_outlined,
        'query': 'Create comprehensive study notes based on the documents in this workspace.',
      },
      {
        'label': 'Generate Quiz',
        'icon': Icons.quiz_outlined,
        'query': 'Generate a quiz with multiple-choice questions to test my understanding of this workspace.',
      },
      {
        'label': 'Key Concepts',
        'icon': Icons.psychology_outlined,
        'query': 'List the key concepts covered in the documents.',
      },
    ];

    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ActionChip(
                elevation: 0,
                pressElevation: 0,
                backgroundColor: colors.surfaceElevated,
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                avatar: Icon(
                  action['icon'] as IconData,
                  size: 14,
                  color: colors.primary,
                ),
                label: Text(
                  action['label'] as String,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  _messageController.text = action['query'] as String;
                  _sendMessage();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeWorkspaceState = ref.watch(activeWorkspaceProvider(widget.workspaceId));
    final sourcesState = ref.watch(sourcesProvider(widget.workspaceId));
    final chatState = ref.watch(chatProvider(widget.workspaceId));

    // Listen for error messages and show a SnackBar
    ref.listen<ChatState>(chatProvider(widget.workspaceId), (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: colors.statusFailed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(chatProvider(widget.workspaceId).notifier).clearError();
      }
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    final String appBarTitle = activeWorkspaceState.when(
      data: (workspace) => workspace.name,
      loading: () => 'Loading...',
      error: (_, __) => 'Workspace',
    );

    final List<src_model.Source> sources = sourcesState.maybeWhen(
      data: (list) => list,
      orElse: () => <src_model.Source>[],
    );

    final hasReadySources = sources.any((s) => s.status == src_model.SourceStatus.ready);

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
        actions: [
          PopupMenuButton<AppFontFamily>(
            icon: Icon(Icons.font_download_outlined, size: 18, color: colors.textSecondary),
            tooltip: 'Change Font style',
            surfaceTintColor: Colors.transparent,
            color: colors.surfaceElevated,
            onSelected: (font) {
              ref.read(fontProvider.notifier).state = font;
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AppFontFamily.sans,
                height: 32,
                child: Text('Sans-Serif', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
              ),
              PopupMenuItem(
                value: AppFontFamily.serif,
                height: 32,
                child: Text('Serif', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
              ),
              PopupMenuItem(
                value: AppFontFamily.mono,
                height: 32,
                child: Text('Mono', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Workspace Settings',
            onPressed: () => _showWorkspaceSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Chat History',
            onPressed: () => _showClearChatConfirmation(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // --- Left Panel: Sources ---
          if (!_isSourcesPanelCollapsed)
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
                              AppRoutes.sourceUpload.replaceAll(':workspaceId', widget.workspaceId),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.keyboard_double_arrow_left_rounded, size: 16),
                          tooltip: 'Collapse Sidebar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _isSourcesPanelCollapsed = true;
                            });
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
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(color: colors.border),
                              ),
                              color: colors.surface,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _showSourceDetailsDialog(context, source),
                                hoverColor: colors.textPrimary.withValues(alpha: 0.06),
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
            )
          else
            Container(
              width: 50,
              decoration: BoxDecoration(
                color: colors.sidebarBackground,
                border: Border(
                  right: BorderSide(color: colors.divider, width: 1),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  IconButton(
                    icon: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 18),
                    tooltip: 'Expand Sidebar',
                    onPressed: () {
                      setState(() {
                        _isSourcesPanelCollapsed = false;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: 'Add Sources',
                    onPressed: () {
                      context.push(
                        AppRoutes.sourceUpload.replaceAll(':workspaceId', widget.workspaceId),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  Expanded(
                    child: sourcesState.when(
                      loading: () => const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, __) => const SizedBox(),
                      data: (sources) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: sources.length,
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

                            Color statusColor;
                            switch (source.status) {
                              case src_model.SourceStatus.processing:
                                statusColor = colors.statusProcessing;
                                break;
                              case src_model.SourceStatus.ready:
                                statusColor = colors.statusReady;
                                break;
                              case src_model.SourceStatus.failed:
                                statusColor = colors.statusFailed;
                                break;
                              case src_model.SourceStatus.pending:
                                statusColor = colors.textSecondary;
                                break;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Tooltip(
                                message: '${source.name} (${source.status.name})',
                                child: InkWell(
                                  onTap: () => _showSourceDetailsDialog(context, source),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Icon(
                                      sourceIcon,
                                      color: statusColor,
                                      size: 16,
                                    ),
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
                  child: !hasReadySources
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
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
                                  sources.isEmpty
                                      ? 'Add sources to get started.'
                                      : 'Click "Start Ingestion" to prepare your sources for chat.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colors.textMuted,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : chatState.messages.isEmpty
                          ? _buildEmptyChatState(context)
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == chatState.messages.length) {
                                  return _buildTypingIndicator(context);
                                }
                                return _buildMessageBubble(context, chatState.messages[index]);
                              },
                            ),
                ),

                // --- Chat Input ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.background,
                    border: Border(
                      top: BorderSide(color: colors.divider, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasReadySources && !chatState.isLoading) ...[
                          _buildQuickActionsRow(context),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                enabled: hasReadySources,
                                minLines: 1,
                                maxLines: 5,
                                style: TextStyle(color: colors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: hasReadySources
                                      ? 'Ask your workspace a question...'
                                      : 'Upload and ingest sources to chat...',
                                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide.none,
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: colors.primary, width: 1.0),
                                  ),
                                  filled: true,
                                  fillColor: colors.surfaceElevated,
                                ),
                                onSubmitted: (_) => hasReadySources ? _sendMessage() : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: (hasReadySources && !chatState.isLoading) ? _sendMessage : null,
                              icon: chatState.isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              color: colors.primary,
                              disabledColor: colors.textMuted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 56, color: colors.primary.withAlpha(150)),
            const SizedBox(height: 20),
            Text(
              'How can I help you explore your workspace today?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select a quick action below or type your question in the box.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _QuickActionCard(
                  title: 'Summarize Workspace',
                  subtitle: 'Get a high-level summary of all documents in this workspace.',
                  icon: Icons.summarize_outlined,
                  onTap: () {
                    _messageController.text = 'Summarize the references across this workspace.';
                    _sendMessage();
                  },
                ),
                _QuickActionCard(
                  title: 'Create Notes',
                  subtitle: 'Create comprehensive study notes based on the documents in this workspace.',
                  icon: Icons.note_alt_outlined,
                  onTap: () {
                    _messageController.text = 'Create comprehensive study notes based on the documents in this workspace.';
                    _sendMessage();
                  },
                ),
                _QuickActionCard(
                  title: 'Generate Quiz',
                  subtitle: 'Generate a quiz with multiple-choice questions to test my understanding of this workspace.',
                  icon: Icons.quiz_outlined,
                  onTap: () {
                    _messageController.text = 'Generate a quiz with multiple-choice questions to test my understanding of this workspace.';
                    _sendMessage();
                  },
                ),
                _QuickActionCard(
                  title: 'Key Concepts',
                  subtitle: 'List the main ideas, terms, and definitions across sources.',
                  icon: Icons.psychology_outlined,
                  onTap: () {
                    _messageController.text = 'List the key concepts covered in the documents.';
                    _sendMessage();
                  },
                ),
                _QuickActionCard(
                  title: 'Create Timeline',
                  subtitle: 'Map out chronological events and dates mentioned in the documents.',
                  icon: Icons.timeline_outlined,
                  onTap: () {
                    _messageController.text = 'Provide a timeline of major events mentioned.';
                    _sendMessage();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final colors = context.colors;
    final isUser = message.isUser;
    final bubbleBg = isUser ? colors.sidebarBackground : colors.primarySubtle;

    // Determine if this is the last assistant response to show suggested follow-up questions
    final chatState = ref.read(chatProvider(widget.workspaceId));
    final isLastMessage = chatState.messages.indexOf(message) == chatState.messages.length - 1;
    final showRecommended = !isUser && isLastMessage && message.recommendedQuestions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.primary.withAlpha(40),
              child: Icon(Icons.hub_rounded, color: colors.primary, size: 16),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isUser ? 12 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 12),
                    ),
                    border: Border.all(color: colors.border),
                  ),
                  child: isUser
                      ? SelectableText(
                          message.text,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.5),
                        )
                      : MarkdownBody(
                          data: message.text,
                          selectable: true,
                          builders: {
                            'code': CodeElementBuilder(context),
                          },
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.5),
                            listBullet: TextStyle(color: colors.primary, fontSize: 14),
                            code: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: colors.textPrimary,
                              backgroundColor: colors.surfaceElevated,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colors.border),
                            ),
                            tableBorder: TableBorder.all(color: colors.border, width: 1),
                            tableBody: TextStyle(color: colors.textPrimary, fontSize: 13.5),
                            tableHead: TextStyle(color: colors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
                if (!isUser) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.citations.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: message.citations.map((cit) => _buildCitationChip(context, cit)).toList(),
                        ),
                      if (message.citations.isNotEmpty) const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        tooltip: 'Copy Response',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        color: colors.textSecondary,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Response copied to clipboard'),
                              backgroundColor: colors.statusReady,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                if (showRecommended) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_outlined, color: colors.primary, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Suggested follow-ups:',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: message.recommendedQuestions.map((q) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: InkWell(
                                  onTap: () {
                                    _messageController.text = q;
                                    _sendMessage();
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: colors.primary.withAlpha(200),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            q,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: colors.textMuted,
                                          size: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.sidebarBackground,
              child: Icon(Icons.person_rounded, color: colors.textSecondary, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCitationChip(BuildContext context, Citation citation) {
    final colors = context.colors;
    return InkWell(
      onTap: () => _showCitationDetails(context, citation),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.sidebarBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '[${citation.index}]',
              style: TextStyle(
                color: colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              citation.sourceName,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.primarySubtle,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Synthesizing response...',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCitationDetails(BuildContext context, Citation citation) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.article_outlined, color: colors.primary),
              const SizedBox(width: 8),
              Text('Footnote [${citation.index}]'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Source Document Name:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(citation.sourceName),
              const SizedBox(height: 12),
              const Text('Raw Chunk Citation ID:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(citation.rawId, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
                AppRoutes.sourceUpload.replaceAll(':workspaceId', widget.workspaceId),
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

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: 250,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border),
          ),
          color: colors.surfaceElevated,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: colors.primarySubtle.withAlpha(80),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: colors.primary, size: 24),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  CodeElementBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    if (!text.contains('\n')) {
      return null;
    }

    String language = '';
    if (element.attributes.containsKey('class')) {
      final className = element.attributes['class'] ?? '';
      if (className.startsWith('language-')) {
        language = className.substring('language-'.length);
      }
    }
    
    final codeText = text.trimRight();

    return CodeBlockWidget(
      codeText: codeText,
      language: language,
    );
  }
}

class CodeBlockWidget extends StatefulWidget {
  final String codeText;
  final String language;

  const CodeBlockWidget({
    super.key,
    required this.codeText,
    required this.language,
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.codeText));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final displayLanguage = widget.language.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.sidebarBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: colors.border),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayLanguage.isEmpty ? 'CODE' : displayLanguage,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: _copyToClipboard,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 13,
                            color: _copied ? colors.statusReady : colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _copied ? 'Copied' : 'Copy',
                            style: TextStyle(
                              color: _copied ? colors.statusReady : colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                widget.codeText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
