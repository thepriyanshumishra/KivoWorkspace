// features/workspace/models/workspace.dart
// Purpose: Defines the Workspace model and workspace status enum.
// Responsibilities: Handles JSON serialization and status mapping.

enum WorkspaceStatus {
  ready,
  processing,
  failed;

  static WorkspaceStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'processing':
        return WorkspaceStatus.processing;
      case 'failed':
        return WorkspaceStatus.failed;
      case 'ready':
      default:
        return WorkspaceStatus.ready;
    }
  }

  String toJson() => name;
}

class Workspace {
  final String id;
  final String name;
  final DateTime createdAt;
  final WorkspaceStatus status;
  final int sourcesCount;

  Workspace({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.status,
    required this.sourcesCount,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: WorkspaceStatus.fromString(json['status'] as String? ?? 'ready'),
      sourcesCount: json['sources_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'status': status.toJson(),
      'sources_count': sourcesCount,
    };
  }

  Workspace copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    WorkspaceStatus? status,
    int? sourcesCount,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      sourcesCount: sourcesCount ?? this.sourcesCount,
    );
  }
}
