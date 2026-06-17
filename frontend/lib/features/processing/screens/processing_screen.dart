// features/processing/screens/processing_screen.dart
// Purpose: Processing screen showing real-time source ingestion progress timeline.
// Responsibilities: Polls processing status, renders dynamic progress bar, handles cancellation, auto-redirects on completion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../source_upload/providers/source_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../models/processing_status.dart';
import '../providers/processing_providers.dart';
import '../services/processing_service.dart';

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

  String _getStepStatus(ProcessingStatus status, String stepKey) {
    if (!status.steps.contains(stepKey)) {
      return 'skipped';
    }
    if (status.completedSteps.contains(stepKey)) {
      return 'done';
    }
    if (status.currentStep == stepKey) {
      if (status.isFailed) return 'failed';
      if (status.isCancelled) return 'failed';
      return 'active';
    }
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
          // Define all standard timeline checkpoints
          const allSteps = [
            'pdf_extraction',
            'image_ocr',
            'audio_transcription',
            'youtube_transcription',
            'website_extraction',
            'text_extraction',
            'embedding_generation',
            'building_knowledge_base',
          ];

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

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
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
                    const SizedBox(height: 40),

                    // --- Progress Indicator ---
                    LinearProgressIndicator(
                      value: status.progress,
                      backgroundColor: colors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation(colors.primary),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      progressMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                          ),
                    ),
                    const SizedBox(height: 40),

                    // --- Timeline steps ---
                    ...allSteps.map((stepKey) {
                      final stepStatus = _getStepStatus(status, stepKey);
                      final label = _getStepLabel(stepKey);

                      Color labelColor;
                      switch (stepStatus) {
                        case 'done':
                          labelColor = colors.textPrimary;
                          break;
                        case 'active':
                          labelColor = colors.primary;
                          break;
                        case 'skipped':
                        case 'pending':
                        default:
                          labelColor = colors.textMuted;
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            _StepStatusIcon(status: stepStatus),
                            const SizedBox(width: 14),
                            Text(
                              label,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: labelColor,
                                    fontWeight: stepStatus == 'active' ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                            ),
                            if (stepStatus == 'skipped') ...[
                              const SizedBox(width: 10),
                              Text(
                                '(Skipped)',
                                style: TextStyle(color: colors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ]
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepStatusIcon extends StatelessWidget {
  final String status;
  const _StepStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    switch (status) {
      case 'done':
        return Icon(Icons.check_circle_rounded, color: colors.statusReady, size: 20);
      case 'active':
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(colors.primary),
          ),
        );
      case 'failed':
        return Icon(Icons.cancel_rounded, color: colors.statusFailed, size: 20);
      case 'skipped':
        return Icon(Icons.remove_circle_outline_rounded, color: colors.textMuted, size: 20);
      case 'pending':
      default:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.border, width: 2),
          ),
        );
    }
  }
}
