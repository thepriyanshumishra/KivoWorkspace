// features/onboarding/screens/model_downloader_screen.dart
// Purpose: Model downloader screen accessed from chat allowing downloading of new models.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/onboarding_state.dart';
import '../providers/onboarding_provider.dart';
import '../services/onboarding_prefs.dart';
import '../../../core/theme/theme_provider.dart';

class ModelDownloaderScreen extends ConsumerStatefulWidget {
  const ModelDownloaderScreen({super.key});

  @override
  ConsumerState<ModelDownloaderScreen> createState() => _ModelDownloaderScreenState();
}

class _ModelDownloaderScreenState extends ConsumerState<ModelDownloaderScreen> {
  final Map<String, bool> _categoryOpenStates = {};
  List<String> _downloadedModels = [];
  bool _isLoading = true;
  
  // Active download state
  String? _activeDownloadingModel;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';
  StreamSubscription? _downloadSub;

  @override
  void initState() {
    super.initState();
    _loadDownloadedModels();
    _categoryOpenStates['Reasoning & Logic'] = true;
  }

  Future<void> _loadDownloadedModels() async {
    final list = await OnboardingPrefs.getDownloadedModels();
    setState(() {
      _downloadedModels = list;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _startDownload(CuratedModel model) async {
    if (_activeDownloadingModel != null) return;

    setState(() {
      _activeDownloadingModel = model.id;
      _downloadProgress = 0.0;
      _downloadStatusText = 'Connecting to Ollama...';
    });

    final service = ref.read(onboardingServiceProvider);
    
    try {
      _downloadSub = service.pullOllamaModel(model.id).listen((progress) {
        setState(() {
          _downloadProgress = progress;
          _downloadStatusText = 'Downloading: ${(progress * 100).toStringAsFixed(0)}%';
        });
      }, onError: (err) {
        _showErrorSnackBar('Download failed: $err');
        _resetActiveDownload();
      }, onDone: () async {
        // Add to downloaded models
        final updated = [..._downloadedModels, model.id];
        await OnboardingPrefs.write({
          'downloadedModels': updated,
          'activeModel': model.id, // Set as active model
        });
        
        _showSuccessSnackBar('${model.name} downloaded successfully!');
        _resetActiveDownload();
        _loadDownloadedModels();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to trigger pull: $e');
      _resetActiveDownload();
    }
  }

  void _resetActiveDownload() {
    _downloadSub?.cancel();
    _downloadSub = null;
    setState(() {
      _activeDownloadingModel = null;
      _downloadProgress = 0.0;
      _downloadStatusText = '';
    });
  }

  Future<void> _deleteModel(String modelId) async {
    final service = ref.read(onboardingServiceProvider);
    final ollamaUrl = await OnboardingPrefs.getOllamaUrl();

    try {
      await service.deleteOllamaModel(modelId, ollamaUrl: ollamaUrl);
      
      final updated = List<String>.from(_downloadedModels)..remove(modelId);
      await OnboardingPrefs.write({
        'downloadedModels': updated,
      });

      final active = await OnboardingPrefs.getActiveModel();
      if (active == modelId) {
        final newActive = updated.isNotEmpty ? updated.first : 'qwen2.5:1.5b';
        await OnboardingPrefs.write({
          'activeModel': newActive,
        });
        ref.read(activeModelProvider.notifier).state = newActive;
      }
      
      _showSuccessSnackBar('Model $modelId deleted successfully!');
      _loadDownloadedModels();
    } catch (e) {
      _showErrorSnackBar('Failed to delete model: $e');
    }
  }

  void _showDeleteConfirmation(String modelId, String modelName) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? const Color(0xFF202020) : const Color(0xFFFBFBFA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
        title: Text(
          'Delete Model?',
          style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete the model "$modelName" ($modelId)? This will remove it from your device and release storage space.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteModel(modelId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.statusFailed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.colors.statusFailed),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: context.colors.statusReady),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final categories = curatedModelRegistry.map((m) => m.category).toSet().toList();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('Download Models', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_downloadedModels.isNotEmpty) ...[
                      Card(
                        margin: const EdgeInsets.only(bottom: 24),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: colors.primary.withValues(alpha: 0.4), width: 1.5),
                        ),
                        color: colors.sidebarBackground,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.download_done_rounded, color: colors.primary, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Installed Models (${_downloadedModels.length})',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _downloadedModels.length,
                                separatorBuilder: (_, __) => const Divider(height: 16),
                                itemBuilder: (context, idx) {
                                  final modelId = _downloadedModels[idx];
                                  final model = curatedModelRegistry.firstWhere(
                                    (m) => m.id == modelId,
                                    orElse: () => CuratedModel(
                                      id: modelId,
                                      name: modelId,
                                      category: 'Custom',
                                      capability: 'Local Model',
                                      size: 'Unknown size',
                                      sizeGb: 0,
                                      ram: 'Unknown',
                                      ramGb: 0,
                                      compatibility: 'Compatible',
                                      description: 'Custom installed model.',
                                    ),
                                  );
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                const SizedBox(width: 8),
                                                Text(model.size, style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(model.description, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      OutlinedButton.icon(
                                        onPressed: () => _showDeleteConfirmation(model.id, model.name),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                                        label: const Text('Delete', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: colors.statusFailed,
                                          side: BorderSide(color: colors.statusFailed.withValues(alpha: 0.5)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    ...categories.map((category) {
                      final models = curatedModelRegistry.where((m) => m.category == category).toList();
                      final isOpen = _categoryOpenStates[category] ?? false;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: colors.border),
                        ),
                        color: colors.sidebarBackground,
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              trailing: Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                              onTap: () => setState(() => _categoryOpenStates[category] = !isOpen),
                            ),
                            if (isOpen)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: models.length,
                                  separatorBuilder: (_, __) => const Divider(height: 16),
                                  itemBuilder: (context, idx) {
                                    final model = models[idx];
                                    final isDownloaded = _downloadedModels.contains(model.id);
                                    final isDownloading = _activeDownloadingModel == model.id;

                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  const SizedBox(width: 8),
                                                  Text(model.size, style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(model.description, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                              const SizedBox(height: 4),
                                              Text('RAM required: ${model.ram}  |  Capability: ${model.capability}',
                                                  style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        if (isDownloaded)
                                          OutlinedButton.icon(
                                            onPressed: () => _showDeleteConfirmation(model.id, model.name),
                                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                                            label: const Text('Delete', style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: colors.statusFailed,
                                              side: BorderSide(color: colors.statusFailed.withValues(alpha: 0.5)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          )
                                        else
                                          ElevatedButton(
                                            onPressed: _activeDownloadingModel != null
                                                ? null
                                                : () => _startDownload(model),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: colors.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                            child: Text(
                                              isDownloading ? 'Pulling...' : 'Download',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),

                // Download Progress Overlay
                if (_activeDownloadingModel != null)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Card(
                      color: colors.sidebarBackground,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Downloading Model Weights',
                              style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 15),
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: _downloadProgress,
                              backgroundColor: colors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _downloadStatusText,
                              style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
