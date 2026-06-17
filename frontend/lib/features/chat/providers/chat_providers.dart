// features/chat/providers/chat_providers.dart
// Purpose: Riverpod state notifier to manage chat message list and loading/error states.
// Responsibilities: Exposes chat messages, appends new messages, and triggers API calls.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _service;
  final String _workspaceId;

  ChatNotifier(this._service, this._workspaceId) : super(ChatState());

  Future<void> sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final userMessage = ChatMessage(
      text: trimmedText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Append user message and set loading
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      errorMessage: null,
    );

    try {
      final responseDto = await _service.sendQuery(_workspaceId, trimmedText);
      final assistantMessage = ChatMessage(
        text: responseDto.answer,
        isUser: false,
        timestamp: DateTime.now(),
        citations: responseDto.citations,
        recommendedQuestions: responseDto.recommendedQuestions,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clearChat() {
    state = ChatState(messages: const []);
  }
}

// family family allows us to instantiate a notifier per active workspace ID.
final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, workspaceId) {
  final service = ref.watch(chatServiceProvider);
  return ChatNotifier(service, workspaceId);
});
