import 'dart:async';

import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/main_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/classifier.dart';
import 'services/history.dart';
import 'services/image_sources.dart';
import 'theme/app_theme.dart';

/// T12 demo without editing code:
/// flutter run --dart-define=MODEL_PATH=assets/model/model_unqant.tflite
const _modelPath = String.fromEnvironment(
  'MODEL_PATH',
  defaultValue: Classifier.defaultModelPath,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // T11: the classifier is created exactly once, here.
  final classifier = Classifier.load(modelPath: _modelPath);

  // T10: smoke test in the debug console.
  if (kDebugMode) {
    unawaited(classifier.then(runSmokeTest, onError: (Object _) {}));
  }

  runApp(TmClassifierApp(classifier: classifier));
}

/// T10. Classifies assets/model/sample.jpg and prints every label.
/// Checks: one line per class, right label on top, sum == 1.0 (± 0.01).
Future<void> runSmokeTest(Classifier classifier) async {
  const path = 'assets/model/sample.jpg';
  final ByteData data;
  try {
    data = await rootBundle.load(path);
  } catch (_) {
    debugPrint(
      '[smoke] $path not found: copy a photo of a trained object '
      'there to run the smoke test.',
    );
    return;
  }
  final predictions = classifier.classify(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  debugPrint(
    '[smoke] ${predictions.length} lines for '
    '${classifier.labels.length} classes',
  );
  for (final p in predictions) {
    debugPrint('[smoke] ${p.label.padRight(12)} ${p.percent}');
  }
  final sum = predictions.fold<double>(0, (s, p) => s + p.confidence);
  final t = classifier.lastTiming!;
  debugPrint(
    '[smoke] sum = ${sum.toStringAsFixed(4)} '
    '(${(sum - 1).abs() <= 0.01 ? 'OK' : 'WRONG'}), '
    'pre-processing ${t.preprocess.inMilliseconds} ms, '
    'inference ${t.inference.inMilliseconds} ms',
  );
}

class TmClassifierApp extends StatefulWidget {
  const TmClassifierApp({super.key, required this.classifier});

  final Future<Classifier> classifier;

  @override
  State<TmClassifierApp> createState() => _TmClassifierAppState();
}

class _TmClassifierAppState extends State<TmClassifierApp> {
  final _history = HistoryStore();
  final _sources = ImageSources();
  late final AppLifecycleListener _lifecycle;

  Classifier? _classifier;
  ModelLoadException? _error;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onDetach: _shutDown);
    widget.classifier.then(
      (c) {
        if (mounted) {
          setState(() => _classifier = c);
        } else {
          c.close();
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(
          () => _error = e is ModelLoadException
              ? e
              : ModelLoadException('Unexpected error: $e', _modelPath),
        );
      },
    );
  }

  /// T11: close() when the app shuts down.
  void _shutDown() {
    _classifier?.close();
    _sources.dispose();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _shutDown();
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classifier = _classifier;
    return MaterialApp(
      title: WelcomeScreen.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _started && classifier != null
          ? MainShell(
              classifier: classifier,
              history: _history,
              sources: _sources,
            )
          : WelcomeScreen(
              classifier: classifier,
              error: _error,
              onGetStarted: () => setState(() => _started = true),
            ),
    );
  }
}
