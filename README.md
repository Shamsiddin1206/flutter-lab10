# TM Classifier (Lab 10: Teach It, Ship It)

A six-class Teachable Machine image classifier (`me`, `nothing`, `phone`, `bokal`, `mouse`, `notebook`)
that runs fully on-device with TensorFlow Lite. It classifies pictures from the camera, the gallery or a URL and shows the
same Result screen for all three. Answers and the evaluation table are in [NOTES.md](NOTES.md).

## First-time setup (about 2 minutes)

This folder holds the app code. The generated Android/iOS project files come from your own Flutter SDK:

```bash
cd tm_classifier
flutter create . --empty --platforms=android,ios --project-name tm_classifier   # adds android/ ios/, keeps our files
dart run tool/configure_platforms.dart                                          # T9: INTERNET + iOS usage texts
flutter pub get
flutter analyze        # → No issues found!
flutter test           # → 9 tests pass
```

`flutter create .` never overwrites existing files: it only adds what is missing. Keep `--empty`, or it also
adds a counter-app `test/widget_test.dart` that does not compile against this app.

## Run

```bash
flutter run                                      # on a real phone or an Android emulator
flutter run --dart-define=MODEL_PATH=assets/model/model_unqant.tflite   # T12 demo: typo in model path
```

Optional: put one photo of a trained object at `assets/model/sample.jpg`. In debug mode the console then prints
the T10 smoke test (`[smoke] …` lines).

## Commit with the lab tags

```bash
dart run tool/commit_parts.dart     # 5 commits, tags p1-model … p5-sources
git push && git push --tags
```

## Structure

```
assets/model/        model_unquant.tflite, labels.txt (+ optional sample.jpg)
lib/main.dart        loads the classifier once, smoke test, app root, close() on shutdown
lib/services/        labels.dart · preprocess.dart · classifier.dart · image_sources.dart · history.dart
lib/theme/           app_theme.dart: the only place with colours, text sizes, radii, spacing
lib/widgets/         prediction_row · status_view (loading/empty/error) · source_badge/thumbnail
lib/screens/         welcome · main_shell (bottom nav) · home · result · history · model
test/                labels_test.dart · preprocess_test.dart
tool/                configure_platforms.dart · commit_parts.dart
docs/                preview.png · design-1.png · design-2.png
```

Design: [Material 3 Design Kit](https://www.figma.com/community/file/1035203688168086460) by Material Design (Google), CC BY 4.0.
