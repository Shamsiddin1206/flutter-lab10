// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusTone { neutral, error }

/// Designed loading / empty / error state: icon in a tinted circle, a title,
/// a sentence and an optional action. Used instead of blank screens.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = StatusTone.neutral,
    this.action,
    this.details,
  });

  final IconData icon;
  final String title;
  final String message;
  final StatusTone tone;
  final Widget? action;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = tone == StatusTone.error;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: isError
                  ? scheme.errorContainer
                  : scheme.secondaryContainer,
              child: Icon(
                icon,
                size: 40,
                color: isError
                    ? scheme.onErrorContainer
                    : scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: SelectableText(
                  details!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error banner for messages that should stay on screen (not a toast).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onClose});

  final String message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, color: scheme.onErrorContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onClose,
              icon: Icon(Icons.close, color: scheme.onErrorContainer),
            ),
        ],
      ),
    );
  }
}
