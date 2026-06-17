// features/chat/models/citation.dart
// Purpose: PODO representation of backend citation metadata.
// Responsibilities: Handles JSON deserialization and fields definition.

class Citation {
  final int index;
  final String rawId;
  final String? sourceId;
  final String sourceName;

  Citation({
    required this.index,
    required this.rawId,
    this.sourceId,
    required this.sourceName,
  });

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      index: json['index'] as int,
      rawId: json['raw_id'] as String,
      sourceId: json['source_id'] as String?,
      sourceName: json['source_name'] as String? ?? 'Source Document',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'raw_id': rawId,
      'source_id': sourceId,
      'source_name': sourceName,
    };
  }
}
