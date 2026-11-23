import 'package:flutter/foundation.dart';

import 'classifier.dart';
import 'image_sources.dart';

/// One finished classification. Holds everything the Result screen needs, so
/// reopening it from History never runs the model again.
class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.bytes,
    required this.predictions,
    required this.source,
    required this.time,
    this.timing,
  });

  final int id;
  final Uint8List bytes;
  final List<Prediction> predictions; // sorted, highest first
  final ImageSourceKind source;
  final DateTime time;
  final InferenceTiming? timing;

  /// What the picture really shows. Set on the Result screen while filling in
  /// the evaluation table (T23); `null` = not evaluated.
  String? expected;

  Prediction get top => predictions.first;
  bool? get isCorrect => expected == null ? null : expected == top.label;
}

/// Every classification of this session, newest first.
class HistoryStore extends ChangeNotifier {
  final List<HistoryEntry> _entries = [];
  int _nextId = 1;

  List<HistoryEntry> get entries => List.unmodifiable(_entries);
  HistoryEntry? get latest => _entries.isEmpty ? null : _entries.first;
  bool get isEmpty => _entries.isEmpty;

  HistoryEntry add({
    required Uint8List bytes,
    required List<Prediction> predictions,
    required ImageSourceKind source,
    InferenceTiming? timing,
  }) {
    final entry = HistoryEntry(
      id: _nextId++,
      bytes: bytes,
      predictions: predictions,
      source: source,
      time: DateTime.now(),
      timing: timing,
    );
    _entries.insert(0, entry);
    notifyListeners();
    return entry;
  }

  void setExpected(HistoryEntry entry, String? label) {
    entry.expected = label;
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  List<HistoryEntry> get evaluated =>
      _entries.reversed.where((e) => e.expected != null).toList();

  /// The evaluation table for NOTES.md, built from real attempts of this
  /// session, oldest first.
  String evaluationMarkdown(List<String> labels) {
    final rows = evaluated;
    final b = StringBuffer()
      ..writeln('| # | Source | Expected | Predicted | % | Correct |')
      ..writeln('|---|--------|----------|-----------|---|---------|');
    for (var i = 0; i < rows.length; i++) {
      final e = rows[i];
      b.writeln(
        '| ${i + 1} | ${e.source.label} | ${e.expected} | '
        '${e.top.label} | ${(e.top.confidence * 100).toStringAsFixed(1)} | '
        '${e.isCorrect! ? 'yes' : 'no'} |',
      );
    }
    final correct = rows.where((e) => e.isCorrect!).length;
    b
      ..writeln()
      ..writeln(
        '**Overall accuracy:** $correct / ${rows.length} = '
        '${rows.isEmpty ? '–' : (correct / rows.length * 100).toStringAsFixed(1)} %',
      )
      ..writeln()
      ..writeln(
        '| Class | Correct / attempts | Mean confidence in the true label |',
      )
      ..writeln(
        '|-------|--------------------|-----------------------------------|',
      );

    String? worst;
    double worstAcc = 2, worstConf = 2;
    for (final label in labels) {
      final attempts = rows.where((e) => e.expected == label).toList();
      if (attempts.isEmpty) {
        b.writeln('| $label | 0 / 0 | – |');
        continue;
      }
      final ok = attempts.where((e) => e.isCorrect!).length;
      final conf =
          attempts
              .map(
                (e) => e.predictions
                    .firstWhere((p) => p.label == label)
                    .confidence,
              )
              .reduce((a, c) => a + c) /
          attempts.length;
      b.writeln(
        '| $label | $ok / ${attempts.length} | '
        '${(conf * 100).toStringAsFixed(1)} % |',
      );
      final acc = ok / attempts.length;
      if (acc < worstAcc || (acc == worstAcc && conf < worstConf)) {
        worst = label;
        worstAcc = acc;
        worstConf = conf;
      }
    }
    b
      ..writeln()
      ..writeln(
        '**Weakest class:** ${worst ?? '–'}'
        '${worst == null ? '' : ' (${(worstAcc * 100).toStringAsFixed(0)} % correct, '
                  'mean confidence ${(worstConf * 100).toStringAsFixed(1)} %)'}',
      );
    return b.toString();
  }
}
