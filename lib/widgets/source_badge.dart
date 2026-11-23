import 'dart:typed_data';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../services/image_sources.dart';
import '../theme/app_theme.dart';

/// Small "Camera / Gallery / Download" pill.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final ImageSourceKind source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.xs),
          Text(
            source.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Square rounded thumbnail decoded at small size (cheap in long lists).
class Thumbnail extends StatelessWidget {
  const Thumbnail({super.key, required this.bytes, this.size = 56});

  final Uint8List bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: px,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              Icon(Icons.broken_image_outlined, color: scheme.outline),
        ),
      ),
    );
  }
}
