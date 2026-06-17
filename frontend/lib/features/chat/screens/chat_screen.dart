// features/chat/screens/chat_screen.dart
// Purpose: Chat screen — primary interaction screen for workspace knowledge.
// Responsibilities: Display chat messages area, input box, citations, loading state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import '../models/citation.dart';
import '../providers/chat_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String workspaceId;

  const ChatScreen({super.key, required this.workspaceId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // --- Messages Area ---
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(context)
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Ask your workspace a question...',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: chatState.isLoading ? null : _sendMessage,
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: colors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text(
              'What would you like to explore?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _QuickActionChip(
                  label: '✦  Summarize Workspace',
                  onTap: () {
                    _messageController.text = 'Summarize the references across this workspace.';
                    _sendMessage();
                  },
                ),
                _QuickActionChip(
                  label: '✦  Key Concepts',
                  onTap: () {
                    _messageController.text = 'List the key concepts covered in the documents.';
                    _sendMessage();
                  },
                ),
                _QuickActionChip(
                  label: '✦  Create Timeline',
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
    final alignment = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleBg = message.isUser ? colors.sidebarBackground : colors.primarySubtle;
    final textStyle = TextStyle(
      color: colors.textPrimary,
      fontSize: 14,
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(message.isUser ? 12 : 0),
                bottomRight: Radius.circular(message.isUser ? 0 : 12),
              ),
              border: Border.all(color: colors.border),
            ),
            child: SelectableText(
              message.text,
              style: textStyle,
            ),
          ),
          if (!message.isUser && message.citations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.citations.map((cit) => _buildCitationChip(context, cit)).toList(),
              ),
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
                'Synthesizing workspace response...',
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
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: colors.sidebarBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
