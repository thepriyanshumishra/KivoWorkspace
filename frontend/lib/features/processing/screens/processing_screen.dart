// features/processing/screens/processing_screen.dart
// Purpose: Processing screen showing real-time source ingestion progress timeline.
// Responsibilities: Polls processing status, renders dynamic progress bar, handles cancellation, auto-redirects on completion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../source_upload/models/source.dart';
import '../../source_upload/providers/source_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../models/processing_status.dart';
import '../providers/processing_providers.dart';
import '../services/processing_service.dart';

class HorizontalStep {
  final String id;
  final String label;
  final IconData icon;
  final List<String> backendSteps;

  HorizontalStep({
    required this.id,
    required this.label,
    required this.icon,
    required this.backendSteps,
  });
}

class ProcessingScreen extends ConsumerWidget {
  final String workspaceId;

  const ProcessingScreen({super.key, required this.workspaceId});

  String _getStepLabel(String stepKey) {
    switch (stepKey) {
      case 'pdf_extraction':
        return 'PDF Extraction';
      case 'image_ocr':
        return 'Image OCR';
      case 'audio_transcription':
        return 'Audio Transcription';
      case 'youtube_transcription':
        return 'YouTube Transcription';
      case 'website_extraction':
        return 'Website Text Extraction';
      case 'text_extraction':
        return 'Pasted Text Processing';
      case 'embedding_generation':
        return 'Embedding Generation';
      case 'building_knowledge_base':
        return 'Building Knowledge Base';
      default:
        return stepKey;
    }
  }

  String getHorizontalStepStatus(HorizontalStep step, ProcessingStatus status) {
    if (status.isReady) return 'done';

    // Check if all backend steps are completed
    final allCompleted = step.backendSteps.every((bs) => status.completedSteps.contains(bs));
    if (allCompleted) return 'done';

    // Check if any of its backend steps is current
    if (step.backendSteps.contains(status.currentStep)) {
      if (status.isFailed || status.isCancelled) return 'failed';
      return 'active';
    }

    // If the pipeline is past this step
    if (status.currentStep != null && status.steps.contains(status.currentStep)) {
      final currentIdx = status.steps.indexOf(status.currentStep!);
      int maxStepIdx = -1;
      for (final bs in step.backendSteps) {
        final idx = status.steps.indexOf(bs);
        if (idx > maxStepIdx) maxStepIdx = idx;
      }
      if (maxStepIdx != -1 && currentIdx > maxStepIdx) {
        return 'done';
      }
    }

    return 'pending';
  }

  List<String> getSubStepsForHorizontalStep(String stepId) {
    switch (stepId) {
      case 'pdf':
        return [
          'Extracting text page-by-page',
          'Structuring paragraphs and layouts',
          'Generating parent-child text chunks',
        ];
      case 'image':
        return [
          'Preprocessing image files',
          'Running Optical Character Recognition (OCR)',
          'Chunking extracted text',
        ];
      case 'audio':
        return [
          'Decompressing audio track',
          'Executing Whisper Speech-to-Text model',
          'Generating time-stamped text chunks',
        ];
      case 'youtube':
        return [
          'Fetching video info and downloading audio stream',
          'Running Whisper Speech-to-Text model',
          'Generating time-stamped text chunks',
        ];
      case 'website':
        return [
          'Fetching URL content',
          'Cleaning HTML tags and navigation text',
          'Chunking article main text',
        ];
      case 'text':
        return [
          'Loading pasted text',
          'Chunking text boundaries',
        ];
      case 'knowledge_base':
        return [
          'Generating high-dimensional vectors (GTE model)',
          'Indexing vectors using FAISS',
          'Compiling chunk mappings & database metadata',
        ];
      default:
        return [];
     }
  }

  String getSubStepStatus(String stepId, int index, String? currentBackendStep, ProcessingStatus status) {
    if (status.isReady) return 'done';

    if (stepId == 'knowledge_base') {
      if (currentBackendStep == 'embedding_generation') {
        if (index == 0) return 'active';
        return 'pending';
      } else if (currentBackendStep == 'building_knowledge_base') {
        if (index == 0) return 'done';
        if (index == 1) return 'active';
        return 'pending';
      }
    }

    // Default simulation for active step
    if (index == 0) return 'done';
    if (index == 1) return 'active';
    return 'pending';
  }

  Future<void> _cancelProcessing(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(processingServiceProvider).cancelProcessing(workspaceId);
      if (context.mounted) {
        context.pop(); // Go back to Upload screen
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: ${e.toString()}'),
            backgroundColor: context.colors.statusFailed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final statusState = ref.watch(processingStatusProvider(workspaceId));
    final sourcesState = ref.watch(sourcesProvider(workspaceId));

    // Listen for completion to auto-navigate back
    ref.listen<AsyncValue<ProcessingStatus>>(processingStatusProvider(workspaceId), (prev, next) {
      next.whenData((data) {
        if (data.isReady) {
          // Invalidate dependencies to reload fresh counts/lists
          ref.invalidate(sourcesProvider(workspaceId));
          ref.read(workspacesProvider.notifier).loadWorkspaces();

          // Auto route to workspace detail view
          if (context.mounted) {
            context.go(AppRoutes.workspace.replaceAll(':workspaceId', workspaceId));
          }
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Sources'),
        automaticallyImplyLeading: false,
        actions: [
          statusState.maybeWhen(
            data: (status) {
              final isProcessing = status.isProcessing;
              return TextButton(
                onPressed: isProcessing ? () => _cancelProcessing(context, ref) : null,
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isProcessing ? colors.statusFailed : colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: statusState.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: colors.statusFailed),
                const SizedBox(height: 16),
                Text('Failed to query status', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Go Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        side: BorderSide(color: colors.border),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(processingStatusProvider(workspaceId)),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        data: (status) {
          final sources = sourcesState.maybeWhen(
            data: (list) => list,
            orElse: () => <Source>[],
          );

          // 1. Identify which source types exist to build horizontal timeline dynamically
          final hasPdf = sources.any((s) => s.type == SourceType.pdf);
          final hasImage = sources.any((s) => s.type == SourceType.image);
          final hasAudio = sources.any((s) => s.type == SourceType.audio);
          final hasYouTube = sources.any((s) => s.type == SourceType.youtube);
          final hasWebsite = sources.any((s) => s.type == SourceType.website);
          final hasText = sources.any((s) => s.type == SourceType.text);

          final horizontalSteps = <HorizontalStep>[];
          if (hasPdf) {
            horizontalSteps.add(HorizontalStep(
              id: 'pdf',
              label: 'PDFs',
              icon: Icons.picture_as_pdf_rounded,
              backendSteps: ['pdf_extraction'],
            ));
          }
          if (hasImage) {
            horizontalSteps.add(HorizontalStep(
              id: 'image',
              label: 'Images',
              icon: Icons.image_rounded,
              backendSteps: ['image_ocr'],
            ));
          }
          if (hasAudio) {
            horizontalSteps.add(HorizontalStep(
              id: 'audio',
              label: 'Audios',
              icon: Icons.audiotrack_rounded,
              backendSteps: ['audio_transcription'],
            ));
          }
          if (hasYouTube) {
            horizontalSteps.add(HorizontalStep(
              id: 'youtube',
              label: 'YouTube',
              icon: Icons.video_library_rounded,
              backendSteps: ['youtube_transcription'],
            ));
          }
          if (hasWebsite) {
            horizontalSteps.add(HorizontalStep(
              id: 'website',
              label: 'Websites',
              icon: Icons.language_rounded,
              backendSteps: ['website_extraction'],
            ));
          }
          if (hasText) {
            horizontalSteps.add(HorizontalStep(
              id: 'text',
              label: 'Texts',
              icon: Icons.article_rounded,
              backendSteps: ['text_extraction'],
            ));
          }
          // Always include Knowledge Base
          horizontalSteps.add(HorizontalStep(
            id: 'knowledge_base',
            label: 'Knowledge Base',
            icon: Icons.hub_rounded,
            backendSteps: ['embedding_generation', 'building_knowledge_base'],
          ));

          // 2. Identify active horizontal step
          HorizontalStep? activeHorizontalStep;
          for (final step in horizontalSteps) {
            if (getHorizontalStepStatus(step, status) == 'active') {
              activeHorizontalStep = step;
              break;
            }
          }
          // Fallbacks for display
          if (activeHorizontalStep == null) {
            if (status.isReady && horizontalSteps.isNotEmpty) {
              activeHorizontalStep = horizontalSteps.last;
            } else if (status.isProcessing && horizontalSteps.isNotEmpty) {
              for (final step in horizontalSteps) {
                if (getHorizontalStepStatus(step, status) == 'pending') {
                  activeHorizontalStep = step;
                  break;
                }
              }
              activeHorizontalStep ??= horizontalSteps.first;
            }
          }

          // 3. Extract sub-steps for current horizontal step
          final subSteps = activeHorizontalStep != null
              ? getSubStepsForHorizontalStep(activeHorizontalStep.id)
              : <String>[];

          // 4. Time remaining estimation logic
          int numPdfs = 0;
          int numImages = 0;
          int numAudios = 0;
          int numYouTubes = 0;
          int numWebsites = 0;
          int numTexts = 0;

          for (final src in sources) {
            switch (src.type) {
              case SourceType.pdf:
                numPdfs++;
                break;
              case SourceType.image:
                numImages++;
                break;
              case SourceType.audio:
                numAudios++;
                break;
              case SourceType.youtube:
                numYouTubes++;
                break;
              case SourceType.website:
                numWebsites++;
                break;
              case SourceType.text:
                numTexts++;
                break;
            }
          }

          final int totalEstimatedSeconds = (numPdfs * 4) +
              (numImages * 3) +
              (numAudios * 12) +
              (numYouTubes * 15) +
              (numWebsites * 3) +
              (numTexts * 1) +
              5; // Base 5s for Knowledge Base

          final int remainingSeconds = (totalEstimatedSeconds * (1.0 - status.progress)).round();

          String remainingText = '';
          if (status.isReady) {
            remainingText = 'Completed!';
          } else if (remainingSeconds <= 0) {
            remainingText = 'Almost done...';
          } else {
            remainingText = 'Estimated time remaining: ${remainingSeconds}s';
          }

          String progressMessage = 'Initializing pipeline...';
          if (status.isProcessing && status.currentStep != null) {
            progressMessage = 'Executing: ${_getStepLabel(status.currentStep!)}';
          } else if (status.isReady) {
            progressMessage = 'Knowledge base built successfully! Redirecting...';
          } else if (status.isCancelled) {
            progressMessage = 'Processing cancelled.';
          } else if (status.isFailed) {
            progressMessage = 'Processing failed.';
          }

          final int progressPercent = (status.progress * 100).round();

          return Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Status Header ---
                      Text(
                        'Building Knowledge Base',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your sources are being processed. This may take a few minutes.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                              fontSize: 13.5,
                            ),
                      ),
                      const SizedBox(height: 32),

                      // --- Horizontal Progress Bar (Timeline) ---
                      if (horizontalSteps.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(horizontalSteps.length * 2 - 1, (index) {
                              if (index.isOdd) {
                                // Connector Line
                                final stepIdx = index ~/ 2;
                                final leftStepStatus = getHorizontalStepStatus(horizontalSteps[stepIdx], status);
                                final rightStepStatus = getHorizontalStepStatus(horizontalSteps[stepIdx + 1], status);

                                Color lineColor = colors.border;
                                if (leftStepStatus == 'done') {
                                  if (rightStepStatus == 'done' || rightStepStatus == 'active') {
                                    lineColor = colors.primary;
                                  } else {
                                    lineColor = colors.primary.withOpacity(0.4);
                                  }
                                }

                                return Expanded(
                                  child: Container(
                                    height: 3,
                                    color: lineColor,
                                  ),
                                );
                              } else {
                                // Step Node
                                final stepIdx = index ~/ 2;
                                final step = horizontalSteps[stepIdx];
                                final stepStatus = getHorizontalStepStatus(step, status);

                                Color nodeBgColor;
                                Color iconColor;
                                Border? border;

                                switch (stepStatus) {
                                  case 'done':
                                    nodeBgColor = colors.statusReady;
                                    iconColor = Colors.white;
                                    break;
                                  case 'active':
                                    nodeBgColor = colors.primary;
                                    iconColor = Colors.white;
                                    break;
                                  case 'failed':
                                    nodeBgColor = colors.statusFailed;
                                    iconColor = Colors.white;
                                    break;
                                  case 'pending':
                                  default:
                                    nodeBgColor = Colors.transparent;
                                    iconColor = colors.textMuted;
                                    border = Border.all(color: colors.border, width: 2);
                                    break;
                                }

                                return Tooltip(
                                  message: step.label,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: nodeBgColor,
                                          border: border,
                                          boxShadow: stepStatus == 'active'
                                              ? [
                                                  BoxShadow(
                                                    color: colors.primary.withOpacity(0.3),
                                                    blurRadius: 8,
                                                    spreadRadius: 2,
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: stepStatus == 'active'
                                              ? Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    const SizedBox(
                                                      width: 28,
                                                      height: 28,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                                      ),
                                                    ),
                                                    Icon(step.icon, color: iconColor, size: 16),
                                                  ],
                                                )
                                              : Icon(
                                                  stepStatus == 'done' ? Icons.check_rounded : step.icon,
                                                  color: iconColor,
                                                  size: 18,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        step.label,
                                        style: TextStyle(
                                          color: stepStatus == 'active'
                                              ? colors.primary
                                              : (stepStatus == 'done' ? colors.textPrimary : colors.textMuted),
                                          fontWeight: stepStatus == 'active' ? FontWeight.w600 : FontWeight.normal,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // --- Progress bar / Linear Progress Indicator ---
                      LinearProgressIndicator(
                        value: status.progress,
                        backgroundColor: colors.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation(colors.primary),
                        borderRadius: BorderRadius.circular(8),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              progressMessage,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$progressPercent% • $remainingText',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // --- Active Vertical checklist ---
                      if (activeHorizontalStep != null && subSteps.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(activeHorizontalStep.icon, color: colors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Currently: ${activeHorizontalStep.label}',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              ...List.generate(subSteps.length, (idx) {
                                final subLabel = subSteps[idx];
                                final subStatus = getSubStepStatus(
                                  activeHorizontalStep!.id,
                                  idx,
                                  status.currentStep,
                                  status,
                                );

                                Color labelColor;
                                Widget iconWidget;

                                switch (subStatus) {
                                  case 'done':
                                    labelColor = colors.textPrimary;
                                    iconWidget = Icon(Icons.check_circle_rounded, color: colors.statusReady, size: 18);
                                    break;
                                  case 'active':
                                    labelColor = colors.primary;
                                    iconWidget = SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(colors.primary),
                                      ),
                                    );
                                    break;
                                  case 'pending':
                                  default:
                                    labelColor = colors.textMuted;
                                    iconWidget = Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: colors.border, width: 1.5),
                                      ),
                                    );
                                    break;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      iconWidget,
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          subLabel,
                                          style: TextStyle(
                                            color: labelColor,
                                            fontWeight: subStatus == 'active' ? FontWeight.w600 : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
