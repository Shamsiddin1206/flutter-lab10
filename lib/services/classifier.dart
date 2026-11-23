import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'labels.dart';
import 'preprocess.dart';

export 'labels.dart' show parseLabels;
export 'preprocess.dart' show decodeForModel, toInputTensor;

/// One label with the model's confidence for it.
class Prediction {
  const Prediction(this.label, this.confidence);
  final String label;
  final double confidence; // 0.0 to 1.0

  String get percent => '${(confidence * 100).toStringAsFixed(1)} %';
}

/// Thrown by [Classifier.load] when the model or the labels cannot be read.
/// Carries the asset path that was expected, so the start-up screen can say
/// exactly what is missing and where.
class ModelLoadException implements Exception {
  const ModelLoadException(this.message, this.expectedPath, [this.cause]);
  final String message;
  final String expectedPath;
  final Object? cause;

  @override
  String toString() => '$message (expected at $expectedPath)';
}

/// How long the last [Classifier.classify] call took, measured with Stopwatch.
class InferenceTiming {
  const InferenceTiming({required this.preprocess, required this.inference});
  final Duration preprocess; // decode + orientation + crop/resize + tensor
  final Duration inference; // interpreter.run only

  Duration get total => preprocess + inference;
}

/// Hides TensorFlow Lite from the rest of the app: bytes in, sorted
/// predictions out. Create it once with [load], share the instance, [close]
/// it when the app shuts down.
class Classifier {
  Classifier._(this._interpreter, this.labels, this.modelPath);

  static const defaultModelPath = 'assets/model/model_unquant.tflite';
  static const defaultLabelsPath = 'assets/model/labels.txt';
  static const inputSize = 224;

  final Interpreter _interpreter;
  final List<String> labels;
  final String modelPath;
  bool _closed = false;

  InferenceTiming? lastTiming;

  String get modelFileName => modelPath.split('/').last;

  /// Shape the model expects, read from the model itself, e.g. [1, 224, 224, 3].
  List<int> get inputShape => _interpreter.getInputTensor(0).shape;

  /// Shape the model produces, e.g. [1, 6].
  List<int> get outputShape => _interpreter.getOutputTensor(0).shape;

  String get inputType => _interpreter.getInputTensor(0).type.toString();

  /// 1. Loading. Slow (reads the file and allocates tensors), so it happens one
  /// time at start-up, never per picture.
  static Future<Classifier> load({
    String modelPath = defaultModelPath,
    String labelsPath = defaultLabelsPath,
  }) async {
    final Interpreter interpreter;
    try {
      interpreter = await Interpreter.fromAsset(modelPath);
    } catch (e) {
      throw ModelLoadException(
        'The model file could not be loaded. Check the file name and that '
        'assets/model/ is listed under flutter: assets: in pubspec.yaml.',
        modelPath,
        e,
      );
    }

    final List<String> labels;
    try {
      labels = parseLabels(await rootBundle.loadString(labelsPath));
    } catch (e) {
      interpreter.close();
      throw ModelLoadException(
        'The labels file could not be read.',
        labelsPath,
        e,
      );
    }

    // The number of classes lives in two places: labels.txt and the model's
    // output tensor. If they disagree every label on screen would be wrong.
    final outputs = interpreter.getOutputTensor(0).shape.last;
    if (labels.length != outputs) {
      interpreter.close();
      throw ModelLoadException(
        'labels.txt has ${labels.length} lines but the model outputs '
        '$outputs classes. Export both files again from Teachable Machine.',
        labelsPath,
      );
    }
    return Classifier._(interpreter, labels, modelPath);
  }

  /// Bytes of any JPEG/PNG/GIF/WebP/BMP image in, every label with its
  /// confidence out, sorted from highest to lowest.
  ///
  /// Throws [FormatException] if the bytes are not a readable image.
  List<Prediction> classify(Uint8List bytes) {
    if (_closed) throw StateError('Classifier is closed');
    final watch = Stopwatch()..start();

    // 2. Decode + EXIF rotation, then the same centre crop as training (224x224).
    // 3. Input tensor, shape [1, 224, 224, 3], channels mapped 0..255 -> -1..1.
    //    Both live in preprocess.dart (pure Dart, unit-tested).
    final input = toInputTensor(decodeForModel(bytes), inputSize);
    final preprocess = watch.elapsed;

    // 4. Output tensor, shape [1, classes], softmax probabilities summing to 1.
    final output = [List<double>.filled(labels.length, 0)];
    _interpreter.run(input, output);
    watch.stop();
    lastTiming = InferenceTiming(
      preprocess: preprocess,
      inference: watch.elapsed - preprocess,
    );

    // 5. Pair index i with label i FIRST, then sort.
    return [
      for (var i = 0; i < labels.length; i++)
        Prediction(labels[i], output.first[i]),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _interpreter.close();
  }
}
