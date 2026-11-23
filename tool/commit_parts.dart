// Creates one commit per lab part with the tags the grading asks for
// (p1-model ... p5-sources). Run from the project folder, inside your git repo:
//
//   dart run tool/commit_parts.dart
//   git push && git push --tags
//
// Only the final tag (p5-sources) is a complete, buildable app; earlier tags
// group the files of each part.
import 'dart:io';

const parts = <(String tag, String message, List<String> paths)>[
  (
    'p1-model',
    'P1: six-class Teachable Machine model, class list, preview screenshot',
    ['NOTES.md', 'docs'],
  ),
  (
    'p2-setup',
    'P2: project, assets/model, dependencies, platform config',
    [
      'pubspec.yaml',
      'pubspec.lock',
      'analysis_options.yaml',
      '.gitignore',
      '.metadata',
      'README.md',
      'assets',
      'android',
      'ios',
      'tool',
    ],
  ),
  (
    'p3-classifier',
    'P3: classifier service, load once, polite errors, unit tests',
    [
      'lib/services/labels.dart',
      'lib/services/preprocess.dart',
      'lib/services/classifier.dart',
      'lib/main.dart',
      'test',
    ],
  ),
  (
    'p4-screens',
    'P4: theme from the Figma design and the five screens',
    ['lib/theme', 'lib/widgets', 'lib/screens'],
  ),
  (
    'p5-sources',
    'P5: camera, gallery and download sources, history, evaluation',
    ['lib/services/image_sources.dart', 'lib/services/history.dart', '.'],
  ),
];

Future<void> main() async {
  if ((await _git(['rev-parse', '--is-inside-work-tree'])).exitCode != 0) {
    stderr.writeln(
      'Not inside a git repository. Run `git init` or clone your '
      'lab repo first, then run this from the project folder.',
    );
    exit(1);
  }
  for (final (tag, message, paths) in parts) {
    final existing = await _git(['tag', '--list', tag]);
    if ((existing.stdout as String).trim().isNotEmpty) {
      stdout.writeln('• $tag already exists, skipped');
      continue;
    }
    final present = paths
        .where(
          (p) => FileSystemEntity.typeSync(p) != FileSystemEntityType.notFound,
        )
        .toList();
    if (present.isNotEmpty) await _git(['add', '--', ...present]);
    final commit = await _git(['commit', '--allow-empty', '-m', message]);
    if (commit.exitCode != 0) {
      stderr.writeln('✗ commit for $tag failed:\n${commit.stderr}');
      exit(1);
    }
    await _git(['tag', tag]);
    stdout.writeln('✓ $tag  $message');
  }
  stdout.writeln('\nNow push:  git push && git push --tags');
}

Future<ProcessResult> _git(List<String> args) => Process.run('git', args);
