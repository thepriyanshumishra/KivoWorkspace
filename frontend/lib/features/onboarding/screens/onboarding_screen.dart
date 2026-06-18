// features/onboarding/screens/onboarding_screen.dart
// Purpose: Interactive 8-stage onboarding UI for system check, model selection, configurations, and styling.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/font_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/onboarding_state.dart';
import '../providers/onboarding_provider.dart';
import 'dart:ui' as ui;
import '../../../core/utils/eyedropper_helper.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Appearance local selection state
  ThemeMode _selectedTheme = ThemeMode.dark;
  AppFontFamily _selectedFont = AppFontFamily.sans;
  Color _selectedAccent = const Color(0xFF0075DE);

  // Accordion open states for Category Selection (Stage 2)
  final Map<String, bool> _categoryOpenStates = {};

  final List<Color> _accentColors = [
    const Color(0xFF0075DE), // Blue
    const Color(0xFF0F7B44), // Green
    const Color(0xFF6366F1), // Indigo
    const Color(0xFFE11D48), // Crimson
  ];

  @override
  void initState() {
    super.initState();
    // Initialize first category open
    _categoryOpenStates['Reasoning & Logic'] = true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    if (progress.activeStage == OnboardingStage.appearance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(themeModeProvider) != _selectedTheme) {
          ref.read(themeModeProvider.notifier).state = _selectedTheme;
        }
        if (ref.read(fontProvider) != _selectedFont) {
          ref.read(fontProvider.notifier).state = _selectedFont;
        }
        if (ref.read(accentColorProvider) != _selectedAccent) {
          ref.read(accentColorProvider.notifier).state = _selectedAccent;
        }
      });
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP STAGES TIMELINE ---
            _buildTimeline(progress.activeStage, colors),
            const Divider(height: 1),

            // --- STAGE SCREEN ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: _buildStageContent(progress, notifier, colors),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TIMELINE HEADER ---
  Widget _buildTimeline(OnboardingStage currentStage, AppColors colors) {
    final stages = [
      'System Check',
      'Models',
      'Summary',
      'Download',
      'Install',
      'Config',
      'Style',
      'Done'
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: colors.sidebarBackground,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(stages.length, (index) {
          final isCompleted = index < currentStage.index;
          final isActive = index == currentStage.index;
          
          return Expanded(
            child: Row(
              children: [
                // Circle Step Indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? colors.statusReady
                        : isActive
                            ? colors.primary
                            : colors.border,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isCompleted
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : colors.textSecondary,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                // Text Label (only shown on active/large screens)
                Flexible(
                  child: Text(
                    stages[index],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? colors.textPrimary : colors.textMuted,
                    ),
                  ),
                ),
                if (index < stages.length - 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        height: 2,
                        color: isCompleted ? colors.statusReady : colors.border,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- STAGE BODY MANAGER ---
  Widget _buildStageContent(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    switch (progress.activeStage) {
      case OnboardingStage.systemCheck:
        return _buildSystemCheck(progress, notifier, colors);
      case OnboardingStage.modelSelection:
        return _buildModelSelection(progress, notifier, colors);
      case OnboardingStage.summary:
        return _buildSummary(progress, notifier, colors);
      case OnboardingStage.downloading:
        return _buildDownloading(progress, notifier, colors);
      case OnboardingStage.installing:
        return _buildInstalling(progress, notifier, colors);
      case OnboardingStage.configurations:
        return _buildConfigurations(progress, notifier, colors);
      case OnboardingStage.appearance:
        return _buildAppearance(progress, notifier, colors);
      case OnboardingStage.done:
        return _buildDone(progress, notifier, colors);
    }
  }

  // --- STAGE 1: SYSTEM CHECK ---
  Widget _buildSystemCheck(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    final specs = progress.systemSpecs;
    if (specs.isEmpty) {
      return const CircularProgressIndicator();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Diagnostics',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Kivo Workspace runs entirely locally. We will inspect your host machine configurations to optimize model compatibility.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 32),

        // Spec Grid Layout
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _specCard('Operating System', specs['os'] ?? 'Unknown', Icons.computer, colors),
            _specCard('Architecture', specs['arch'] ?? 'Unknown', Icons.architecture, colors),
            _specCard('CPU Cores', '${specs['cores']} Cores', Icons.memory, colors),
            _specCard('System RAM', specs['ram'] ?? 'Unknown', Icons.speed, colors),
            _specCard('Available Storage', specs['disk'] ?? 'Unknown', Icons.storage, colors),
            _specCard('Hardware Graphics', specs['gpu'] ?? 'Unknown', Icons.developer_board, colors),
          ],
        ),

        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () => notifier.runSystemChecks(),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Re-scan'),
            ),
            ElevatedButton(
              onPressed: () => notifier.nextStage(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Next: Choose Models'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _specCard(String title, String value, IconData icon, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.sidebarBackground,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: colors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: colors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 13, color: colors.textPrimary, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STAGE 2: MODEL SELECTION ---
  Widget _buildModelSelection(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    // Unique categories from registry
    final categories = curatedModelRegistry.map((m) => m.category).toSet().toList();

    // Recommendation Parameters
    final ramString = progress.systemSpecs['ramValue'] ?? '8.0';
    final ramGb = double.tryParse(ramString)?.round() ?? 8;
    final hasGPU = progress.systemSpecs['gpuValue'] == 'true';

    // Build Dynamic Recommended Models List
    final recommendedModels = curatedModelRegistry.where((model) {
      return model.matchesSystemSpecs(systemRamGb: ramGb, hasHardwareAcceleration: hasGPU);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Local Models',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose one or more local LLMs to download. You will be able to switch between downloaded models seamlessly inside your chats.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Collapsible Accordion Categories
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length + 1, // +1 for Recommended Category at top
          itemBuilder: (context, index) {
            if (index == 0) {
              // Recommended category
              final isOpen = _categoryOpenStates['Recommended'] ?? true;
              return _buildCategoryAccordion(
                '⭐ Recommended Models (System Optimized)',
                recommendedModels.take(4).toList(),
                isOpen,
                progress,
                notifier,
                colors,
                onToggle: () => setState(() => _categoryOpenStates['Recommended'] = !isOpen),
              );
            }

            final category = categories[index - 1];
            final models = curatedModelRegistry.where((m) => m.category == category).toList();
            final isOpen = _categoryOpenStates[category] ?? false;

            return _buildCategoryAccordion(
              category,
              models,
              isOpen,
              progress,
              notifier,
              colors,
              onToggle: () => setState(() => _categoryOpenStates[category] = !isOpen),
            );
          },
        ),

        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => notifier.prevStage(),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: progress.selectedModelIds.isEmpty
                  ? null
                  : () => notifier.nextStage(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Next: Installation Summary'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryAccordion(
    String categoryName,
    List<CuratedModel> models,
    bool isOpen,
    OnboardingProgress progress,
    OnboardingNotifier notifier,
    AppColors colors, {
    required VoidCallback onToggle,
  }) {
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
            title: Text(
              categoryName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            trailing: Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
            onTap: onToggle,
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: models.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemBuilder: (context, idx) {
                  final model = models[idx];
                  final isSelected = progress.selectedModelIds.contains(model.id);

                  return InkWell(
                    onTap: () => notifier.toggleModelSelection(model.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.05)
                            : colors.background,
                        border: Border.all(
                          color: isSelected ? colors.primary : colors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  model.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Checkbox(
                                value: isSelected,
                                onChanged: (_) => notifier.toggleModelSelection(model.id),
                                activeColor: colors.primary,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            model.description,
                            style: TextStyle(fontSize: 10.5, color: colors.textSecondary, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Download: ${model.size}',
                                style: TextStyle(fontSize: 10, color: colors.textMuted),
                              ),
                              Text(
                                'RAM: ${model.ram}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- STAGE 3: SUMMARY ---
  Widget _buildSummary(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    final downloadSize = notifier.getCalculatedDownloadSize();
    final freeDiskString = progress.systemSpecs['diskValue'] ?? '20.0';
    final freeDisk = double.tryParse(freeDiskString) ?? 20.0;
    final installSize = downloadSize * 2.0; // Estimate footprint as double download size
    final spaceEnough = freeDisk > installSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Installation Summary',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Please review the packages to be downloaded and installed on your host machine.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 24),

        // List of items
        Container(
          decoration: BoxDecoration(
            color: colors.sidebarBackground,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _summaryItemTile(
                'FFmpeg Binary',
                progress.isFfmpegInstalled ? 'Already Installed (Skipped)' : 'Required for audio transcription',
                progress.isFfmpegInstalled ? '0 MB' : '70 MB',
                colors,
                isInstalled: progress.isFfmpegInstalled,
              ),
              _summaryItemTile(
                'Tesseract OCR',
                progress.isTesseractInstalled ? 'Already Installed (Skipped)' : 'Required for extracting text from images',
                progress.isTesseractInstalled ? '0 MB' : '40 MB',
                colors,
                isInstalled: progress.isTesseractInstalled,
              ),
              _summaryItemTile(
                'Embedding Engine',
                progress.isEmbeddingModelInstalled ? 'Already Installed (Skipped)' : 'ONNX quantized model (gte-multilingual-base)',
                progress.isEmbeddingModelInstalled ? '0 MB' : '600 MB',
                colors,
                isInstalled: progress.isEmbeddingModelInstalled,
              ),
              _summaryItemTile(
                'Python Libraries',
                progress.isPythonInstalled ? 'Already Installed (Skipped)' : 'Quantized tokenizers, FAISS, ONNX-Runtime core dependencies',
                progress.isPythonInstalled ? '0 MB' : '400 MB',
                colors,
                isInstalled: progress.isPythonInstalled,
              ),
              ...progress.selectedModelIds.map((id) {
                final match = curatedModelRegistry.firstWhere((m) => m.id == id);
                final isModelInstalled = progress.installedOllamaModels.any((m) => m == id || m.startsWith('$id:') || id.startsWith('$m:'));
                return _summaryItemTile(
                  match.name,
                  isModelInstalled ? 'Already Installed (Skipped)' : 'Ollama Local LLM',
                  isModelInstalled ? '0 MB' : match.size,
                  colors,
                  isInstalled: isModelInstalled,
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Disk details row
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: spaceEnough ? colors.statusReadyBg : colors.statusFailedBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                spaceEnough ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: spaceEnough ? colors.statusReady : colors.statusFailed,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Download Size: ${downloadSize.toStringAsFixed(1)} GB  |  Footprint on Disk: ${installSize.toStringAsFixed(1)} GB',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: spaceEnough ? colors.statusReady : colors.statusFailed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your device has ${freeDisk.toStringAsFixed(1)} GB free storage remaining.',
                      style: TextStyle(
                        fontSize: 12,
                        color: spaceEnough ? colors.statusReady : colors.statusFailed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => notifier.prevStage(),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: !spaceEnough ? null : () => notifier.nextStage(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Proceed to Download'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryItemTile(String name, String description, String size, AppColors colors, {bool isInstalled = false}) {
    return ListTile(
      leading: Icon(
        isInstalled ? Icons.check_circle : Icons.check_circle_outline,
        size: 16,
        color: isInstalled ? colors.statusReady : colors.primary,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
      subtitle: Text(description, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
      trailing: Text(size, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: isInstalled ? colors.statusReady : colors.textPrimary)),
    );
  }

  // --- STAGE 4: DOWNLOADING ---
  Widget _buildDownloading(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Text(
          'Downloading Workspace Patch',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Please do not close the application. Downloading required local binaries.',
          style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
        ),
        const SizedBox(height: 48),

        // Speed details row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Download speed: ${progress.downloadSpeed} MB/s', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            Text('Time remaining: ${progress.downloadEta}', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.downloadProgress,
            minHeight: 12,
            backgroundColor: colors.border,
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${progress.downloadedMb.toStringAsFixed(0)} MB / ${progress.totalMb.toStringAsFixed(0)} MB',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
          ],
        ),

        // Connectivity Retry Overlay
        if (!progress.isInternetConnected)
          Container(
            margin: const EdgeInsets.only(top: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.statusFailedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.statusFailed),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: colors.statusFailed),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Internet Connection Available',
                        style: TextStyle(fontWeight: FontWeight.bold, color: colors.statusFailed, fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Please verify your system network connection to continue.',
                        style: TextStyle(color: colors.statusFailed, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => notifier.retryDownload(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.statusFailed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

        const SizedBox(height: 80),
      ],
    );
  }

  // --- STAGE 5: INSTALLING ---
  Widget _buildInstalling(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Extracting & Installing Binaries',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Setting up binary folders and setting file execution permissions.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 32),

        // Installer Checklist
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.sidebarBackground,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: progress.installStatus.entries.map((entry) {
              final isDone = entry.value.contains('Completed');
              final isInProgress = entry.value.contains('Extracting');
              return ListTile(
                leading: isInProgress
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        isDone ? Icons.check_circle : Icons.circle_outlined,
                        color: isDone ? colors.statusReady : colors.textMuted,
                        size: 18,
                      ),
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                trailing: Text(entry.value, style: TextStyle(fontSize: 12, color: isInProgress ? colors.primary : colors.textSecondary)),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- STAGE 6: CONFIGURATIONS ---
  Widget _buildConfigurations(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Configurations',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Launching local backend subprocess and pulling selected LLM weights into Ollama.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 32),

        // Config Checklist
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.sidebarBackground,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: progress.installStatus.entries.map((entry) {
              final isDone = entry.value.contains('Completed') || entry.value.contains('Ready') || entry.value.contains('Online');
              final isInProgress = entry.value.contains('Progress') || entry.value.contains('Downloading') || entry.value.contains('Spawning');
              return ListTile(
                leading: isInProgress
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        isDone ? Icons.check_circle : Icons.circle_outlined,
                        color: isDone ? colors.statusReady : colors.textMuted,
                        size: 18,
                      ),
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                trailing: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12,
                    color: isInProgress ? colors.primary : isDone ? colors.statusReady : colors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- STAGE 7: APPEARANCE ---
  Widget _buildAppearance(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    final isDark = _selectedTheme == ThemeMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customize Appearance',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure Kivo Workspace theme, fonts, and accents according to your preference.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 32),

        // 1. Theme selection
        const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: [
            _outlinedButtonIcon(
              onPressed: () {
                setState(() => _selectedTheme = ThemeMode.light);
                ref.read(themeModeProvider.notifier).state = ThemeMode.light;
              },
              icon: Icons.light_mode_outlined,
              label: 'Light Mode',
              isSelected: _selectedTheme == ThemeMode.light,
              colors: colors,
            ),
            const SizedBox(width: 16),
            _outlinedButtonIcon(
              onPressed: () {
                setState(() => _selectedTheme = ThemeMode.dark);
                ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
              },
              icon: Icons.dark_mode_outlined,
              label: 'Dark Mode',
              isSelected: _selectedTheme == ThemeMode.dark,
              colors: colors,
            ),
          ],
        ),
        const SizedBox(height: 28),

        // 2. Typography selection
        const Text('Active Typography', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        SegmentedButton<AppFontFamily>(
          segments: const [
            ButtonSegment(value: AppFontFamily.sans, label: Text('Sans Serif')),
            ButtonSegment(value: AppFontFamily.serif, label: Text('Serif')),
            ButtonSegment(value: AppFontFamily.mono, label: Text('Mono (Stealth)')),
          ],
          selected: {_selectedFont},
          onSelectionChanged: (val) {
            setState(() => _selectedFont = val.first);
            ref.read(fontProvider.notifier).state = val.first;
          },
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // 3. Accent highlight selection
        const Text('Accent Highlight Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: [
            ..._accentColors.map((color) {
              final isSelected = _selectedAccent == color;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedAccent = color);
                  ref.read(accentColorProvider.notifier).state = color;
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: isDark ? Colors.white : Colors.black, width: 2.5)
                        : Border.all(color: Colors.transparent),
                  ),
                ),
              );
            }),

            // Palette custom color selector (Rainbow sweep gradient)
            GestureDetector(
              onTap: () => _showCustomColorPickerDialog(context, colors),
              child: Tooltip(
                message: 'Custom Color Palette',
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: !_accentColors.contains(_selectedAccent)
                          ? (isDark ? Colors.white : Colors.black)
                          : colors.border,
                      width: !_accentColors.contains(_selectedAccent) ? 2.5 : 1,
                    ),
                    gradient: const SweepGradient(
                      colors: [
                        Colors.red,
                        Colors.yellow,
                        Colors.green,
                        Colors.cyan,
                        Colors.blue,
                        Color(0xFFFF00FF),
                        Colors.red,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    size: 16,
                    color: !_accentColors.contains(_selectedAccent)
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),

            // Eyedropper (Pick from anywhere on screen)
            GestureDetector(
              onTap: () async {
                final Color? picked = await EyedropperHelper.pickColor(context);
                if (picked != null) {
                  setState(() => _selectedAccent = picked);
                  ref.read(accentColorProvider.notifier).state = picked;
                }
              },
              child: Tooltip(
                message: 'Pick Color from Screen',
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                    color: colors.sidebarBackground,
                  ),
                  child: Icon(
                    Icons.colorize_rounded,
                    size: 16,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () {
                // Restore defaults
                setState(() {
                  _selectedTheme = ThemeMode.dark;
                  _selectedFont = AppFontFamily.sans;
                  _selectedAccent = const Color(0xFF0075DE);
                });
                ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
                ref.read(fontProvider.notifier).state = AppFontFamily.sans;
                ref.read(accentColorProvider.notifier).state = const Color(0xFF0075DE);
              },
              child: const Text('Restore Defaults'),
            ),
            ElevatedButton(
              onPressed: () {
                notifier.completeOnboarding(
                  theme: _selectedTheme,
                  font: _selectedFont.name,
                  accentHex: '#${_selectedAccent.toARGB32().toRadixString(16).substring(2)}',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text('Submit & Finish'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _outlinedButtonIcon({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isSelected,
    required AppColors colors,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: isSelected ? colors.primary : colors.textSecondary),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? colors.primary : colors.textSecondary,
        side: BorderSide(color: isSelected ? colors.primary : colors.border, width: isSelected ? 2 : 1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  // --- STAGE 8: DONE SCREEN ---
  Widget _buildDone(OnboardingProgress progress, OnboardingNotifier notifier, AppColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(
          Icons.celebration_rounded,
          size: 72,
          color: Color(0xFF0F7B44),
        ),
        const SizedBox(height: 24),
        const Text(
          'All Systems Ready! 🚀',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'All setups are done and we are ready to make some boom.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 48),

        ElevatedButton(
          onPressed: () {
            // Apply preferences to providers directly
            ref.read(themeModeProvider.notifier).state = _selectedTheme;
            ref.read(fontProvider.notifier).state = _selectedFont;
            ref.read(accentColorProvider.notifier).state = _selectedAccent;

            // Route to home dashboard
            context.go('/');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.statusReady,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Text(
            'Get Started',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 64),
      ],
    );
  }

  Future<void> _showCustomColorPickerDialog(BuildContext context, AppColors colors) async {
    final Color originalColor = _selectedAccent;
    Color currentColor = _selectedAccent;

    while (true) {
      if (!context.mounted) break;
      final Color? result = await showDialog<Color>(
        context: context,
        builder: (context) => CustomColorPickerDialog(
          initialColor: currentColor,
          colors: colors,
        ),
      );

      if (result == null) {
        // Revert to original color on cancel
        ref.read(accentColorProvider.notifier).state = originalColor;
        break;
      }

      if (result.toARGB32() == 0) {
        // Sentinel color: run eyedropper
        if (!context.mounted) break;
        final Color? picked = await EyedropperHelper.pickColor(context);
        if (picked != null) {
          currentColor = picked;
          ref.read(accentColorProvider.notifier).state = picked;
        }
      } else {
        // Apply final chosen color
        setState(() => _selectedAccent = result);
        ref.read(accentColorProvider.notifier).state = result;
        break;
      }
    }
  }
}

class CustomColorPickerDialog extends ConsumerStatefulWidget {
  final Color initialColor;
  final AppColors colors;

  const CustomColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.colors,
  });

  @override
  ConsumerState<CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends ConsumerState<CustomColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    final hsv = HSVColor.fromColor(_selectedColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    final hexStr = _selectedColor.toARGB32().toRadixString(16).padLeft(8, '0');
    _hexController = TextEditingController(
      text: hexStr.substring(2).toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _onSVChange(Offset localPos, double width, double height) {
    setState(() {
      _saturation = (localPos.dx / width).clamp(0.0, 1.0);
      _value = (1.0 - (localPos.dy / height)).clamp(0.0, 1.0);
      _selectedColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
      _hexController.text = _selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    });
    ref.read(accentColorProvider.notifier).state = _selectedColor;
  }

  void _onHueChange(double newHue) {
    setState(() {
      _hue = newHue;
      _selectedColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
      _hexController.text = _selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    });
    ref.read(accentColorProvider.notifier).state = _selectedColor;
  }

  void _onHexChange(String hex) {
    String cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      try {
        final color = Color(int.parse('FF$cleanHex', radix: 16));
        final hsv = HSVColor.fromColor(color);
        setState(() {
          _selectedColor = color;
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
        ref.read(accentColorProvider.notifier).state = _selectedColor;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final isDark = _selectedColor.computeLuminance() < 0.5;

    return Dialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Custom Accent Color',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: colors.textSecondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // SV Picker Box
            LayoutBuilder(
              builder: (context, constraints) {
                return SVBoxPicker(
                  hue: _hue,
                  saturation: _saturation,
                  value: _value,
                  onChange: (offset) => _onSVChange(
                    offset,
                    constraints.maxWidth,
                    180,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Hue Slider
            HueSlider(
              hue: _hue,
              onChange: _onHueChange,
            ),
            const SizedBox(height: 20),

            // Color display, hex input & eyedropper
            Row(
              children: [
                // Color preview circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Hex Input Field
                Expanded(
                  child: TextField(
                    controller: _hexController,
                    onChanged: _onHexChange,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      prefixText: '# ',
                      prefixStyle: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.bold),
                      labelText: 'Hex Code',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _selectedColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Eyedropper within dialog
                IconButton(
                  icon: const Icon(Icons.colorize_rounded),
                  color: colors.textPrimary,
                  tooltip: 'Pick from screen',
                  onPressed: () {
                    Navigator.pop(context, const Color(0x00000000));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dialog actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _selectedColor);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: isDark ? Colors.white : Colors.black,
                  ),
                  child: const Text('Apply Accent'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SVBoxPicker extends StatelessWidget {
  final double hue;
  final double saturation;
  final double value;
  final ValueChanged<Offset> onChange;

  const SVBoxPicker({
    super.key,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (details) => onChange(details.localPosition),
      onPanUpdate: (details) => onChange(details.localPosition),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final cursorX = saturation * width;
          final cursorY = (1.0 - value) * height;

          return Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: HSVColorPainter(hue),
                    ),
                  ),
                ),
                Positioned(
                  left: (cursorX - 8).clamp(-8.0, width - 8.0),
                  top: (cursorY - 8).clamp(-8.0, height - 8.0),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 4)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class HSVColorPainter extends CustomPainter {
  final double hue;

  HSVColorPainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final hsvColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    final horizontalShader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, 0),
      [Colors.white, hsvColor],
    );
    final horizontalPaint = Paint()..shader = horizontalShader;
    canvas.drawRect(rect, horizontalPaint);

    final verticalShader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, size.height),
      [Colors.transparent, Colors.black],
    );
    final verticalPaint = Paint()
      ..shader = verticalShader
      ..blendMode = BlendMode.multiply;
    canvas.drawRect(rect, verticalPaint);
  }

  @override
  bool shouldRepaint(covariant HSVColorPainter oldDelegate) => oldDelegate.hue != hue;
}

class HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChange;

  const HueSlider({
    super.key,
    required this.hue,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (details) => _updateHue(details.localPosition, context),
      onPanUpdate: (details) => _updateHue(details.localPosition, context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cursorX = (hue / 360.0) * width;

          return Container(
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CustomPaint(
                      painter: HueSliderPainter(),
                    ),
                  ),
                ),
                Positioned(
                  left: (cursorX - 6).clamp(-6.0, width - 6.0),
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.black26),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 2)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateHue(Offset localPos, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final double percent = (localPos.dx / width).clamp(0.0, 1.0);
    onChange(percent * 360.0);
  }
}

class HueSliderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final colors = [
      const Color(0xFFFF0000), // Red
      const Color(0xFFFFFF00), // Yellow
      const Color(0xFF00FF00), // Green
      const Color(0xFF00FFFF), // Cyan
      const Color(0xFF0000FF), // Blue
      const Color(0xFFFF00FF), // Magenta
      const Color(0xFFFF0000), // Red
    ];
    final shader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, 0),
      colors,
    );
    final paint = Paint()..shader = shader;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
