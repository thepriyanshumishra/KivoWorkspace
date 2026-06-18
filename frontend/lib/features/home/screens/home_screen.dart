import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/font_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/router/app_router.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/providers/workspace_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0; // 0: Dashboard, 1: Inventory, 2: Analytics
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateWorkspaceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateWorkspaceDialog(),
    );
  }

  void _showGlobalSettings(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF202020) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final currentFont = ref.watch(fontProvider);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Theme', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.read(themeModeProvider.notifier).state = ThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined, size: 14),
                      label: const Text('Light'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? colors.textSecondary : colors.primary,
                        side: BorderSide(color: !isDark ? colors.primary : colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined, size: 14),
                      label: const Text('Dark'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? colors.primary : colors.textSecondary,
                        side: BorderSide(color: isDark ? colors.primary : colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Typography', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textMuted)),
                const SizedBox(height: 8),
                SegmentedButton<AppFontFamily>(
                  segments: const [
                    ButtonSegment(value: AppFontFamily.sans, label: Text('Sans')),
                    ButtonSegment(value: AppFontFamily.serif, label: Text('Serif')),
                    ButtonSegment(value: AppFontFamily.mono, label: Text('Mono')),
                  ],
                  selected: {currentFont},
                  onSelectionChanged: (val) {
                    ref.read(fontProvider.notifier).state = val.first;
                  },
                  style: ButtonStyle(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Kivo Workspace v1.0.2-stealth',
                  style: TextStyle(fontSize: 11, color: colors.textMuted, fontFamily: 'IBM Plex Mono'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopTabBar(BuildContext context) {
    final colors = context.colors;

    final tabs = ['Dashboard', 'Inventory', 'Analytics'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Logo Title
          Text(
            'Kivo Workspace',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 32),
          // Tabs
          ...tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final title = entry.value;
            final isSelected = _selectedTab == idx;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTab = idx;
                });
              },
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? colors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final workspacesState = ref.watch(workspacesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 52,
        title: _buildTopTabBar(context),
        actions: [
          // Theme switch
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 18,
              color: colors.textSecondary,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          // System Health icon
          IconButton(
            icon: Icon(Icons.settings_input_component_outlined, size: 18, color: colors.textSecondary),
            tooltip: 'System Health',
            onPressed: () {
              context.push('/system-health');
            },
          ),
          // Global Settings (theme + font picker)
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 18, color: colors.textSecondary),
            tooltip: 'Settings',
            onPressed: () {
              _showGlobalSettings(context);
            },
          ),
          // Profile avatar placeholder
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFEDEDEB),
              child: Text(
                'U',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colors.divider),
        ),
      ),
      body: workspacesState.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: colors.statusFailed),
              const SizedBox(height: 16),
              Text('Failed to load workspaces', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(error.toString(), style: TextStyle(color: colors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(workspacesProvider.notifier).loadWorkspaces(),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
        data: (workspaces) {
          final query = _searchController.text.trim().toLowerCase();
          final filteredWorkspaces = workspaces.where((w) {
            return w.name.toLowerCase().contains(query);
          }).toList();

          return SingleChildScrollView(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Centered Search Bar
                    Center(
                      child: Container(
                        width: double.infinity,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF202020) : const Color(0xFFFBFBFA),
                          border: Border.all(color: colors.border, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(Icons.search_rounded, size: 16, color: colors.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: colors.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Search workspaces...',
                                  hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFEDEDEB),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'Ctrl+K',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'IBM Plex Mono',
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Workspaces Section Header
                    Row(
                      children: [
                        Text(
                          'Workspaces',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => _showCreateWorkspaceDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text('New Workspace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Workspaces List Content
                    if (filteredWorkspaces.isEmpty)
                      _buildEmptyState(context)
                    else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredWorkspaces.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _WorkspaceCard(workspace: filteredWorkspaces[index]);
                        },
                      ),
                    ],
                    const SizedBox(height: 32),
                    // Universal Search divider CTA
                    InkWell(
                      onTap: () => context.push('/multi-workspace-chat'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF202020) : const Color(0xFFFAF9F7),
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.manage_search_rounded, size: 16, color: colors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Universal Search',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                  ),
                                  Text(
                                    'Search across all workspaces at once.',
                                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, size: 15, color: colors.textMuted),
                          ],
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 36, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No workspaces found',
            style: TextStyle(color: colors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends ConsumerStatefulWidget {
  final Workspace workspace;

  const _WorkspaceCard({required this.workspace});

  @override
  ConsumerState<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends ConsumerState<_WorkspaceCard> {
  bool _isHovered = false;

  void _showRenameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _RenameWorkspaceDialog(workspace: widget.workspace),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DeleteConfirmDialog(workspace: widget.workspace),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine states mapping
    final isProcessing = widget.workspace.status == WorkspaceStatus.processing;
    final isFailed = widget.workspace.status == WorkspaceStatus.failed;

    // Styled Card
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          // Go to source upload if no sources, else chat workspace
          if (widget.workspace.sourcesCount == 0) {
            context.push('/workspace/${widget.workspace.id}/upload');
          } else if (isProcessing) {
            context.push('/workspace/${widget.workspace.id}/processing');
          } else {
            context.push('/workspace/${widget.workspace.id}');
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isFailed
                ? (isDark ? const Color(0xFF3F1E1E) : const Color(0xFFFFECEB))
                : (isDark ? const Color(0xFF202020) : Colors.white),
            border: Border.all(
              color: isFailed
                  ? colors.statusFailed.withValues(alpha: 0.5)
                  : colors.border,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left status dot/spinner
              if (isProcessing)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 12),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isFailed
                        ? colors.statusFailed
                        : colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.workspace.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (isProcessing) ...[
                      // Progress Bar inside the card
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: const LinearProgressIndicator(
                                value: 0.6,
                                minHeight: 4,
                                backgroundColor: Color(0xFFEDEDEB),
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '60%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ] else if (isFailed) ...[
                      // Failed status callout
                      Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 13, color: colors.statusFailed),
                          const SizedBox(width: 4),
                          Text(
                            'Ingestion failed: timeout',
                            style: TextStyle(
                              color: colors.statusFailed,
                              fontSize: 11.5,
                              fontFamily: 'IBM Plex Mono',
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Normal details
                      Text(
                        '${widget.workspace.sourcesCount} Sources  |  4.2 MB  |  Updated 2h ago',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Hover choices or stealth actions menu
              if (_isHovered)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 16, color: colors.textSecondary),
                      tooltip: 'Rename',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showRenameDialog(context),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 16, color: colors.statusFailed),
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showDeleteConfirmDialog(context),
                    ),
                  ],
                )
              else
                Icon(
                  Icons.more_horiz_rounded,
                  size: 16,
                  color: colors.textMuted,
                ),
            ],
          ),
        ),
      ),
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
        context.push(
          AppRoutes.sourceUpload.replaceAll(':workspaceId', newW.id),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? const Color(0xFF202020) : const Color(0xFFFBFBFA),
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
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
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
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 13.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
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
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
        Navigator.of(context).pop();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? const Color(0xFF202020) : const Color(0xFFFBFBFA),
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
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
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
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
        Navigator.of(context).pop();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? const Color(0xFF202020) : const Color(0xFFFBFBFA),
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
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'Are you sure you want to delete "${widget.workspace.name}"? This will permanently delete the workspace and all of its processed sources. This action cannot be undone.',
        style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.statusFailed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
