// features/chat/providers/chat_providers.dart
// Purpose: Riverpod state notifier to manage chat message list and loading/error states.
// Responsibilities: Exposes chat messages, appends new messages, and triggers API calls.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/citation.dart';
import '../services/chat_service.dart';
import '../../../core/theme/theme_provider.dart';

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

class QueryRecord {
  final String workspaceId;
  final String question;
  final int latencyMs;
  final DateTime timestamp;

  QueryRecord({
    required this.workspaceId,
    required this.question,
    required this.latencyMs,
    required this.timestamp,
  });
}

class QueryHistoryNotifier extends StateNotifier<List<QueryRecord>> {
  QueryHistoryNotifier() : super([]);

  void addRecord(String workspaceId, String question, int latencyMs) {
    state = [
      ...state,
      QueryRecord(
        workspaceId: workspaceId,
        question: question,
        latencyMs: latencyMs,
        timestamp: DateTime.now(),
      ),
    ];
  }
}

final queryHistoryProvider = StateNotifierProvider<QueryHistoryNotifier, List<QueryRecord>>((ref) {
  return QueryHistoryNotifier();
});

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _service;
  final String _workspaceId;
  final Ref _ref;

  ChatNotifier(this._service, this._workspaceId, this._ref) : super(ChatState());

  Future<void> sendMessage(String text, {bool isStrict = true}) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    final userMessage = ChatMessage(
      text: trimmedText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // 1. Append user message, set loading=true to trigger skeleton loader
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      errorMessage: null,
    );

    try {
      // 2. Prepare blank assistant message placeholder
      var assistantMessage = ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
      );

      // Append placeholder
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
      );

      // 3. Connect to stream
      final temp = _ref.read(ragTemperatureProvider);
      final threshold = _ref.read(ragSimilarityThresholdProvider);
      final ollamaUrl = _ref.read(ollamaUrlProvider);
      final activeModel = _ref.read(activeModelProvider);

      final stream = _service.sendQueryStream(
        _workspaceId,
        trimmedText,
        isStrict: isStrict,
        temperature: temp,
        similarityThreshold: threshold,
        ollamaUrl: ollamaUrl,
        modelName: activeModel,
      );
      bool isFirstToken = true;

      await for (final event in stream) {
        if (event.trim().isEmpty) continue;
        final Map<String, dynamic> data = json.decode(event);

        if (data['done'] == true) {
          // Final chunk with full clean answer and citation metadata
          final citationsJson = data['citations'] as List<dynamic>? ?? [];
          final recQuestions = List<String>.from(data['recommended_questions'] as List<dynamic>? ?? []);
          final finalCitations = citationsJson.map((c) => Citation.fromJson(c)).toList();
          final finalAnswer = data['answer'] as String? ?? assistantMessage.text;
          final latencyMs = data['latency_ms'] as int? ?? 0;
          _ref.read(queryHistoryProvider.notifier).addRecord(_workspaceId, trimmedText, latencyMs);

          state = state.copyWith(
            messages: [
              ...state.messages.sublist(0, state.messages.length - 1),
              assistantMessage.copyWith(
                text: finalAnswer,
                citations: finalCitations,
                recommendedQuestions: recQuestions,
              ),
            ],
            isLoading: false,
          );
        } else {
          // Regular token chunk
          final token = data['token'] as String? ?? '';
          
          assistantMessage = assistantMessage.copyWith(
            text: assistantMessage.text + token,
          );

          state = state.copyWith(
            messages: [
              ...state.messages.sublist(0, state.messages.length - 1),
              assistantMessage,
            ],
            // Set isLoading to false on first token to hide the skeleton loader
            isLoading: isFirstToken ? false : state.isLoading,
          );
          
          isFirstToken = false;
        }
      }
    } catch (e) {
      // Clean up placeholder if it is empty and failed
      var currentMessages = state.messages;
      if (currentMessages.isNotEmpty && !currentMessages.last.isUser && currentMessages.last.text.isEmpty) {
        currentMessages = currentMessages.sublist(0, currentMessages.length - 1);
      }
      state = state.copyWith(
        messages: currentMessages,
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
  return ChatNotifier(service, workspaceId, ref);
});

class UniversalChatNotifier extends StateNotifier<ChatState> {
  final ChatService _service;
  final Ref _ref;

  UniversalChatNotifier(this._service, this._ref) : super(ChatState());

  Future<void> sendUniversalMessage(List<String> workspaceIds, String text, {bool isStrict = true}) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || workspaceIds.isEmpty) return;

    final userMessage = ChatMessage(
      text: trimmedText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Append user message, set loading=true
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      errorMessage: null,
    );

    try {
      // Prepare assistant message placeholder
      var assistantMessage = ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
      );

      // Append placeholder
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
      );

      // Retrieve overriding parameters
      final temp = _ref.read(ragTemperatureProvider);
      final threshold = _ref.read(ragSimilarityThresholdProvider);
      final ollamaUrl = _ref.read(ollamaUrlProvider);
      final activeModel = _ref.read(activeModelProvider);

      final stream = _service.sendUniversalQueryStream(
        workspaceIds,
        trimmedText,
        isStrict: isStrict,
        temperature: temp,
        similarityThreshold: threshold,
        ollamaUrl: ollamaUrl,
        modelName: activeModel,
      );
      bool isFirstToken = true;

      await for (final event in stream) {
        if (event.trim().isEmpty) continue;
        final Map<String, dynamic> data = json.decode(event);

        if (data['done'] == true) {
          final citationsJson = data['citations'] as List<dynamic>? ?? [];
          final recQuestions = List<String>.from(data['recommended_questions'] as List<dynamic>? ?? []);
          final finalCitations = citationsJson.map((c) => Citation.fromJson(c)).toList();
          final finalAnswer = data['answer'] as String? ?? assistantMessage.text;
          final latencyMs = data['latency_ms'] as int? ?? 0;
          _ref.read(queryHistoryProvider.notifier).addRecord('universal', trimmedText, latencyMs);

          state = state.copyWith(
            messages: [
              ...state.messages.sublist(0, state.messages.length - 1),
              assistantMessage.copyWith(
                text: finalAnswer,
                citations: finalCitations,
                recommendedQuestions: recQuestions,
              ),
            ],
            isLoading: false,
          );
        } else {
          final token = data['token'] as String? ?? '';
          
          assistantMessage = assistantMessage.copyWith(
            text: assistantMessage.text + token,
          );

          state = state.copyWith(
            messages: [
              ...state.messages.sublist(0, state.messages.length - 1),
              assistantMessage,
            ],
            isLoading: isFirstToken ? false : state.isLoading,
          );
          
          isFirstToken = false;
        }
      }
    } catch (e) {
      var currentMessages = state.messages;
      if (currentMessages.isNotEmpty && !currentMessages.last.isUser && currentMessages.last.text.isEmpty) {
        currentMessages = currentMessages.sublist(0, currentMessages.length - 1);
      }
      state = state.copyWith(
        messages: currentMessages,
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

final universalChatProvider = StateNotifierProvider<UniversalChatNotifier, ChatState>((ref) {
  final service = ref.watch(chatServiceProvider);
  return UniversalChatNotifier(service, ref);
});

