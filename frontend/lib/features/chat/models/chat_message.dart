// features/chat/models/chat_message.dart
// Purpose: Class representing a single chat message in the UI thread.
// Responsibilities: Stores text, role, citations, and timestamp.

import 'citation.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Citation> citations;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.citations = const [],
  });
}
