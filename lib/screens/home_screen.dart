// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/classifier.dart';
import '../services/history.dart';
import '../services/image_sources.dart';
import '../theme/app_theme.dart';
import '../widgets/source_badge.dart';
import '../widgets/status_view.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.classifier,
    required this.history,
    required this.sources,
  });

  final Classifier classifier;
  final HistoryStore history;
  final ImageSources sources;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _busy; // what we are doing right now, or null when idle
  String? _error; // last readable error message

  Future<void> _classifyFrom(
    ImageSourceKind kind,
    Future<Uint8List?> Function() getBytes,
  ) async {
    if (_busy != null) return;
    setState(() {
      _error = null;
      _busy = kind == ImageSourceKind.download
          ? 'Downloading the image…'
          : 'Waiting for the ${kind.label.toLowerCase()}…';
    });
    try {
      final bytes = await getBytes();
      if (bytes == null || !mounted) return; // cancelled: nothing changes

      setState(() => _busy = 'Classifying…');
      // classify() blocks the UI thread; let this frame paint first.
      await WidgetsBinding.instance.endOfFrame;

      final predictions = widget.classifier.classify(bytes);
      final entry = widget.history.add(
        bytes: bytes,
        predictions: predictions,
        source: kind,
        timing: widget.classifier.lastTiming,
      );
      if (!mounted) return;
      setState(() => _busy = null);
      await Navigator.of(context).push(
        ResultScreen.route(
          entry: entry,
          history: widget.history,
          labels: widget.classifier.labels,
        ),
      );
    } on FormatException catch (e) {
      _fail(e.message);
    } on DownloadException catch (e) {
      _fail(e.message);
    } on PlatformException catch (e) {
      _fail(
        e.code.contains('access_denied') || e.code.contains('denied')
            ? 'Access to the ${kind.label.toLowerCase()} was denied. '
                  'Allow it in the phone settings and try again.'
            : 'Could not open the ${kind.label.toLowerCase()}: '
                  '${e.message ?? e.code}',
      );
    } catch (e) {
      _fail('Something went wrong: $e');
    } finally {
      if (mounted && _busy != null) setState(() => _busy = null);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = null;
      _error = message;
    });
  }

  Future<void> _askForUrl() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => const _UrlDialog(),
    );
    if (url == null || url.trim().isEmpty) return;
    await _classifyFrom(
      ImageSourceKind.download,
      () => widget.sources.fromUrl(url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idle = _busy == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text('Classify a picture', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pick where the picture comes from. All three end on the same '
            'result screen.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_busy != null) ...[
            _BusyCard(message: _busy!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_error != null) ...[
            ErrorBanner(
              message: _error!,
              onClose: () => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _ActionCard(
            icon: Icons.photo_camera_outlined,
            title: 'Take a photo',
            subtitle: 'Use the phone camera',
            primary: true,
            onTap: idle
                ? () => _classifyFrom(
                    ImageSourceKind.camera,
                    widget.sources.fromCamera,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _ActionCard(
            icon: Icons.photo_library_outlined,
            title: 'Choose from gallery',
            subtitle: 'Photos, screenshots or saved downloads',
            onTap: idle
                ? () => _classifyFrom(
                    ImageSourceKind.gallery,
                    widget.sources.fromGallery,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _ActionCard(
            icon: Icons.cloud_download_outlined,
            title: 'Download an image',
            subtitle: 'Paste the address of a picture on the web',
            onTap: idle ? _askForUrl : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Most recent result', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ListenableBuilder(
            listenable: widget.history,
            builder: (context, _) {
              final latest = widget.history.latest;
              if (latest == null) return const _NoResultYet();
              return _LatestCard(
                entry: latest,
                onTap: () => Navigator.of(context).push(
                  ResultScreen.route(
                    entry: latest,
                    history: widget.history,
                    labels: widget.classifier.labels,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final bg = primary ? scheme.primaryContainer : scheme.surfaceContainerLow;
    final fg = primary ? scheme.onPrimaryContainer : scheme.onSurface;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: primary
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap, // InkWell = ripple + highlight as the pressed state
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primary
                      ? scheme.primary
                      : scheme.secondaryContainer,
                  child: Icon(
                    icon,
                    color: primary
                        ? scheme.onPrimary
                        : scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(color: fg),
                      ),
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: primary
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BusyCard extends StatelessWidget {
  const _BusyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _NoResultYet extends StatelessWidget {
  const _NoResultYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.image_search_outlined, color: scheme.outline, size: 32),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                'No result yet. Your latest classification will show up here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Thumbnail(bytes: entry.bytes, size: 64),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.top.label,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      entry.top.percent,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SourceBadge(source: entry.source),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for an image address. Owns its TextEditingController.
class _UrlDialog extends StatefulWidget {
  const _UrlDialog();

  @override
  State<_UrlDialog> createState() => _UrlDialogState();
}

class _UrlDialogState extends State<_UrlDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.cloud_download_outlined),
      title: const Text('Download an image'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste the address of a picture (long-press an image in the '
            'browser → Copy image address).',
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Image address',
              hintText: 'https://example.com/photo.jpg',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _controller.text.trim().isEmpty ? null : _submit,
            child: const Text('Download'),
          ),
        ),
      ],
    );
  }
}
