// features/chat/screens/chat_screen.dart
// Purpose: Chat screen — primary interaction screen for workspace knowledge.
// Sprint 0: Placeholder layout only. No chat logic yet.
// Responsibilities: Display chat messages area, input box, quick action buttons.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class ChatScreen extends StatelessWidget {
  final String workspaceId;

  const ChatScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // --- Messages Area ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- Quick Actions (Empty State) ---
                  Text(
                    'What would you like to explore?',
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                  ),
                  const SizedBox(height: 24),
                  const Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _QuickActionChip(label: '✦  Summarize'),
                      _QuickActionChip(label: '✦  Create Notes'),
                      _QuickActionChip(label: '✦  Generate Quiz'),
                      _QuickActionChip(label: '✦  Key Concepts'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- Chat Input ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.divider, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: TextField(
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Ask your workspace a question...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.send_rounded),
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  const _QuickActionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: () {
        // Sprint 14: Will trigger quick action
      },
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
