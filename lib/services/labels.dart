/// Pure Dart: no Flutter, no plugins, so it runs in a plain unit test.
library;

/// `"0 Mug\n1 Bottle\n"` becomes `['Mug', 'Bottle']`.
///
/// Handles Windows line endings (`\r\n`), blank lines anywhere in the file and
/// labels that contain spaces (`2 Car keys` -> `Car keys`). Only the leading
/// index and the whitespace after it are removed.
List<String> parseLabels(String raw) => [
  for (final line in raw.split('\n'))
    if (line.trim().isNotEmpty)
      line.trim().replaceFirst(RegExp(r'^\d+\s+'), ''),
];
