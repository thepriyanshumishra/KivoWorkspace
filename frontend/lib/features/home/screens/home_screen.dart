// features/home/screens/home_screen.dart
// Purpose: Home screen showing workspaces grid and actions.
// Responsibilities: Displays list/grid of workspaces, shows dialogs for CRUD.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final workspacesState = ref.watch(workspacesProvider);

    return Scaffold(
      // Custom AppBar: leading clearance for macOS traffic lights.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 90,
        leading: const SizedBox.shrink(),
        toolbarHeight: 48,
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateWorkspaceDialog(context, ref),
              icon: const Icon(Icons.add, size: 15),
              label: const Text('New Workspace'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: colors.divider),
        ),
      ),

      body: workspacesState.when(
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: colors.statusFailed),
                const SizedBox(height: 16),
                Text(
                  'Failed to load workspaces',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.read(workspacesProvider.notifier).loadWorkspaces(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (workspaces) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(40, 36, 40, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Page Heading ---
                Text(
                  'My Workspaces',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 22,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Select a workspace to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textMuted,
                        fontSize: 13.5,
                      ),
                ),

                const SizedBox(height: 32),

                // --- Workspaces Content ---
                Expanded(
                  child: workspaces.isEmpty
                      ? _buildEmptyState(context, ref)
                      : _buildGrid(context, ref, workspaces),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.sidebarBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Icon(
              Icons.workspaces_outlined,
              size: 28,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No workspaces yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Click "New Workspace" above to create your first one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<Workspace> workspaces) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute responsive cross axis count
        final double width = constraints.maxWidth;
        final int crossAxisCount = (width / 280).floor().clamp(1, 4);

        return GridView.builder(
          itemCount: workspaces.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final workspace = workspaces[index];
            return _WorkspaceCard(workspace: workspace);
          },
        );
      },
    );
  }

  void _showCreateWorkspaceDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _CreateWorkspaceDialog(),
    );
  }
}

class _WorkspaceCard extends ConsumerWidget {
  final Workspace workspace;

  const _WorkspaceCard({required this.workspace});

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    // Map status colors
    Color statusColor;
    Color statusBg;
    String statusText;

    switch (workspace.status) {
      case WorkspaceStatus.processing:
        statusColor = colors.statusProcessing;
        statusBg = colors.statusProcessingBg;
        statusText = 'Processing';
        break;
      case WorkspaceStatus.failed:
        statusColor = colors.statusFailed;
        statusBg = colors.statusFailedBg;
        statusText = 'Failed';
        break;
      case WorkspaceStatus.ready:
        statusColor = colors.statusReady;
        statusBg = colors.statusReadyBg;
        statusText = 'Ready';
        break;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.border, width: 1),
      ),
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Go to Workspace screen
          context.push(
            AppRoutes.workspace.replaceAll(':workspaceId', workspace.id),
          );
        },
        hoverColor: colors.primarySubtle.withAlpha(100),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Icon/Badge & Actions menu
              Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.sidebarBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.folder_open_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                  ),
                  const Spacer(),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Dropdown Action Menu
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, size: 18, color: colors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 100),
                    surfaceTintColor: Colors.transparent,
                    color: colors.surfaceElevated,
                    onSelected: (value) {
                      if (value == 'rename') {
                        _showRenameDialog(context, ref);
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'rename',
                        height: 32,
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 14, color: colors.textSecondary),
                            const SizedBox(width: 8),
                            Text('Rename', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        height: 32,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 14, color: colors.statusFailed),
                            const SizedBox(width: 8),
                            Text('Delete', style: TextStyle(fontSize: 13, color: colors.statusFailed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Title
              Text(
                workspace.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),

              const Spacer(),

              // Footer: Sources Count & Created Date
              Row(
                children: [
                  Icon(Icons.description_outlined, size: 13, color: colors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    workspace.sourcesCount == 1 ? '1 source' : '${workspace.sourcesCount} sources',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(workspace.createdAt),
                    style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _RenameWorkspaceDialog(workspace: workspace),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _DeleteConfirmDialog(workspace: workspace),
    );
  }
}

class _CreateWorkspaceDialog extends ConsumerStatefulWidget {
  const _CreateWorkspaceDialog();

  @override
  ConsumerState<_CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends ConsumerState<_CreateWorkspaceDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final name = _controller.text.trim();
      final newW = await ref.read(workspacesProvider.notifier).createWorkspace(name);
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        // Automatically navigate to the new workspace detail screen
        context.push(
          AppRoutes.workspace.replaceAll(':workspaceId', newW.id),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
      title: Text(
        'New Workspace',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a name for your new workspace knowledge base.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g., Q3 Marketing Campaign',
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Workspace name is required';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _RenameWorkspaceDialog extends ConsumerStatefulWidget {
  final Workspace workspace;

  const _RenameWorkspaceDialog({required this.workspace});

  @override
  ConsumerState<_RenameWorkspaceDialog> createState() => _RenameWorkspaceDialogState();
}

class _RenameWorkspaceDialogState extends ConsumerState<_RenameWorkspaceDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.workspace.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final name = _controller.text.trim();
      await ref.read(workspacesProvider.notifier).renameWorkspace(widget.workspace.id, name);
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
      title: Text(
        'Rename Workspace',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a new name for "${widget.workspace.name}".',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Workspace Name',
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Workspace name is required';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _DeleteConfirmDialog extends ConsumerStatefulWidget {
  final Workspace workspace;

  const _DeleteConfirmDialog({required this.workspace});

  @override
  ConsumerState<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends ConsumerState<_DeleteConfirmDialog> {
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(workspacesProvider.notifier).deleteWorkspace(widget.workspace.id);
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
      title: Text(
        'Delete Workspace',
        style: TextStyle(
          color: colors.statusFailed,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        'Are you sure you want to delete "${widget.workspace.name}"? This will permanently delete the workspace and all of its processed sources. This action cannot be undone.',
        style: TextStyle(color: colors.textSecondary, fontSize: 13.5, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.statusFailed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}
