// T9: platform configuration. Run once, after `flutter create`:
//
//   dart run tool/configure_platforms.dart
//
// Adds the INTERNET permission to the Android manifest (release builds need it
// for "Download an image") and the camera / photo-library usage sentences to
// the iOS Info.plist. Safe to run twice: it only adds what is missing.
import 'dart:io';

void main() {
  var ok = true;
  ok &= _android();
  ok &= _ios();
  if (!ok) exitCode = 1;
}

bool _android() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stderr.writeln(
      '✗ ${f.path} not found. Run first:\n'
      '  flutter create . --empty --platforms=android,ios --project-name tm_classifier',
    );
    return false;
  }
  var xml = f.readAsStringSync();
  const permission =
      '<uses-permission android:name="android.permission.INTERNET"/>';
  if (xml.contains('android.permission.INTERNET')) {
    stdout.writeln('• Android: INTERNET permission already present');
    return true;
  }
  final open = RegExp(r'<manifest[^>]*>').firstMatch(xml);
  if (open == null) {
    stderr.writeln('✗ Android: no <manifest> tag in ${f.path}');
    return false;
  }
  xml = xml.replaceRange(open.end, open.end, '\n    $permission');
  f.writeAsStringSync(xml);
  stdout.writeln('✓ Android: added INTERNET permission');
  return true;
}

bool _ios() {
  final f = File('ios/Runner/Info.plist');
  if (!f.existsSync()) {
    stdout.writeln(
      '• iOS: ${f.path} not found (skipped; fine if you only '
      'build for Android)',
    );
    return true;
  }
  var plist = f.readAsStringSync();
  const entries = {
    'NSCameraUsageDescription':
        'The camera is used to photograph an object so the app can recognise it on your phone.',
    'NSPhotoLibraryUsageDescription':
        'Your photo library is used to pick a picture for the app to recognise on your phone.',
  };
  final missing = entries.entries.where((e) => !plist.contains(e.key)).toList();
  if (missing.isEmpty) {
    stdout.writeln('• iOS: usage descriptions already present');
    return true;
  }
  final end = plist.lastIndexOf('</dict>');
  if (end < 0) {
    stderr.writeln('✗ iOS: no </dict> in ${f.path}');
    return false;
  }
  final insert = StringBuffer();
  for (final e in missing) {
    insert
      ..writeln('\t<key>${e.key}</key>')
      ..writeln('\t<string>${e.value}</string>');
  }
  plist = plist.replaceRange(end, end, insert.toString());
  f.writeAsStringSync(plist);
  stdout.writeln('✓ iOS: added ${missing.map((e) => e.key).join(', ')}');
  return true;
}
