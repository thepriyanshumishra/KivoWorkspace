// features/workspace/providers/workspace_providers.dart
// Purpose: Riverpod providers and state notifier to manage workspace collection and active workspace.
// Responsibilities: Exposes loading states, handles CRUD, and handles errors cleanly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace.dart';
import '../services/workspace_service.dart';

final workspacesProvider = StateNotifierProvider<WorkspacesNotifier, AsyncValue<List<Workspace>>>((ref) {
  final service = ref.watch(workspaceServiceProvider);
  return WorkspacesNotifier(service);
});

class WorkspacesNotifier extends StateNotifier<AsyncValue<List<Workspace>>> {
  final WorkspaceService _service;

  WorkspacesNotifier(this._service) : super(const AsyncValue.loading()) {
    loadWorkspaces();
  }

  Future<void> loadWorkspaces() async {
    try {
      // Keep displaying old data if it is just a refresh
      final hasData = state.hasValue;
      if (!hasData) {
        state = const AsyncValue.loading();
      }
      final list = await _service.getWorkspaces();
      state = AsyncValue.data(list);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<Workspace> createWorkspace(String name) async {
    try {
      final newWorkspace = await _service.createWorkspace(name);
      state.whenData((currentList) {
        state = AsyncValue.data([newWorkspace, ...currentList]);
      });
      return newWorkspace;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> renameWorkspace(String id, String newName) async {
    try {
      final updated = await _service.renameWorkspace(id, newName);
      state.whenData((currentList) {
        final updatedList = currentList.map((w) => w.id == id ? updated : w).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateWorkspaceSettings(String id, {String? name, String? instructions}) async {
    try {
      final updated = await _service.updateWorkspace(id, name: name, instructions: instructions);
      state.whenData((currentList) {
        final updatedList = currentList.map((w) => w.id == id ? updated : w).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteWorkspace(String id) async {
    try {
      await _service.deleteWorkspace(id);
      state.whenData((currentList) {
        final updatedList = currentList.where((w) => w.id != id).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (e) {
      rethrow;
    }
  }
}

// Active workspace provider that fetches details dynamically.
// We auto-dispose so that it doesn't leak memory when switching workspaces.
final activeWorkspaceProvider = FutureProvider.autoDispose.family<Workspace, String>((ref, id) async {
  final service = ref.watch(workspaceServiceProvider);
  return service.getWorkspace(id);
});
