# Lab 10 · Teach It, Ship It: Teachable Machine Image Classifier

**Student:** Shamsiddin Tohirov **Repo tags:** `p1-model` … `p5-sources`

---

## Part 1: Train and export the model

### T1 Class list

| # | Label (exactly as in `labels.txt`) | What it is | Samples |
|---|---|---|---|
| 0 | `me` | One of us, face and upper body in front of the camera | ✏️ |
| 1 | `nothing` | **Background class**: empty desk / wall, no object | ✏️ |
| 2 | `phone` | A smartphone | ✏️ |
| 3 | `bokal` | A drinking glass (бокал) | ✏️ |
| 4 | `mouse` | A computer mouse | ✏️ |
| 5 | `notebook` | ✏️ paper notebook / laptop | ✏️ |

Six classes, 50 + samples each, taken with the laptop webcam at different
distances, angles, backgrounds and lighting, held by both partners.
Every class reached ≥ 80 % on a fresh pose in the preview → `docs/preview.png`.

Export: TensorFlow Lite → **Floating point** → `converted_tflite.zip` →
`model_unquant.tflite` (2 091 932 bytes) + `labels.txt` (6 lines, `0 me` … `5 notebook`).

Checked with the TFLite interpreter: input `[1, 224, 224, 3] float32`, output `[1, 6] float32`.

### Q: What does the model answer for an object that is none of our classes? How does the background class change that?

It always answers one of the six labels. The last layer is a **softmax**: the six
outputs are forced to add up to 1, and there is no "unknown" output. So a
shoe still gets 100 % shared out between `me … notebook`, and often most of it goes
to one class, because softmax exaggerates small differences. Test: an image of
random noise with a red rectangle came out as **phone 96.6 %**.

The background class `nothing` gives the model an honest place to put "no object
here": an empty desk, a wall, a dark or blank frame. Test: an all-black input gave
`nothing` 93.9 % and an all-white one 94.9 %. Without that class an empty desk would be
forced into an object class. It does **not** solve the general problem. `nothing` only
learned what *our* empty desk looks like, so a truly new object (a shoe on the desk)
can still be labelled `phone` or `mouse` with high confidence.

### Q: Floating point vs Quantized: size, input type, and what Dart would have to do

| | Floating point (`model_unquant.tflite`) | Quantized (`model.tflite`) |
|---|---|---|
| Size | ≈ 2.0 MB (weights as 32-bit floats) | ≈ 4× smaller, ≈ 0.5–0.6 MB (8-bit integers) |
| Input | `float32 [1,224,224,3]`, values −1 … 1 | `uint8 [1,224,224,3]`, values 0 … 255 |
| Output | `float32 [1,N]`, probabilities 0 … 1 | `uint8 [1,N]`, 0 … 255 |
| Dart code | `value / 127.5 − 1` per channel, output used as is | **no** normalisation, feed raw ints; output list of `int`, divide by 255 |

Quantized is smaller and often faster on phone CPUs but may lose a little accuracy.

---

## Part 2: Project, assets and dependencies

- `assets/model/model_unquant.tflite` and `assets/model/labels.txt` at the project root (next to `lib/`).
- `pubspec.yaml` declares `assets: - assets/model/` and the four packages under `dependencies:`
  (`tflite_flutter`, `image_picker`, `image`, `http`).
- Android: `INTERNET` permission in `android/app/src/main/AndroidManifest.xml`.
  iOS: `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist`.
  Both added by `dart run tool/configure_platforms.dart`.
- No `minSdk` change was needed (tflite_flutter needs minSdk 19 and image_picker less than Flutter's default).

### Q: `assets/model/` vs `assets/`: which files does each bundle?

A directory entry bundles **only the files directly inside that folder. It does not
include subfolders.**
- `assets/model/` → `model_unquant.tflite`, `labels.txt` (and `sample.jpg`). ✔
- `assets/` → only files lying directly in `assets/`, of which there are none. The model in
  `assets/model/` would **not** be bundled, so `Interpreter.fromAsset` fails with
  "Unable to load asset". Each subfolder needs its own line.

### Q: Why can `image` and `http` run in a plain Dart unit test while `tflite_flutter` and `image_picker` cannot?

`image` and `http` are **pure Dart**. They only need the Dart VM, which a unit
test has. Our tests in `test/preprocess_test.dart` decode and resize images with
`image` on the laptop.
- `tflite_flutter` calls the native TensorFlow Lite C library through `dart:ffi`. That `.so`/framework
  is packaged inside the Android/iOS app and is not present on the test machine. It also
  loads the model through `rootBundle`, which needs the Flutter asset bundle.
- `image_picker` sends a message over a **platform channel** to Android/iOS code that opens
  the camera or gallery. In a unit test no platform is on the other end, so you get a
  `MissingPluginException`.

---

## Part 3: The classifier (`lib/services/`)

| File | Content |
|---|---|
| `labels.dart` | `parseLabels`, pure Dart |
| `preprocess.dart` | `decodeForModel` (decode, RGB8, EXIF rotation) and `toInputTensor` (centre crop 224×224, −1…1), pure Dart |
| `classifier.dart` | `Classifier.load` / `classify` / `close`, `Prediction`, `ModelLoadException`, Stopwatch timing |

Changes against the sample, and why:
1. **Decoder whitelist.** `img.decodeImage` also tries the **TGA** format, which has no
   signature bytes. A text file then "looks like" a TGA header. Tested with `labels.txt`: the
   decoder threw `ImageException: Image dimensions 26478x12810 exceed …` instead of returning
   `null`. We accept only JPEG, PNG, GIF, WebP and BMP, and turn every failure into a `FormatException`.
2. Grayscale, alpha, palette and 16-bit images are converted to 8-bit RGB first. Otherwise `p.g` and `p.b`
   would be wrong for a 1-channel PNG.
3. Resize uses `Interpolation.average` (box filter) instead of the default nearest-neighbour.
   This is closer to the browser resize Teachable Machine used and has less aliasing when shrinking 1024 px to 224 px.
4. `load` checks that `labels.length` equals the model's output size and refuses to start if not.

### T10 Smoke test
In debug mode `main()` classifies `assets/model/sample.jpg` and prints:
```
[smoke] 6 lines for 6 classes
[smoke] phone        97.3 %      
...
[smoke] sum = 1.0000 (OK), pre-processing … ms, inference … ms
```

### T11 Load once, share everywhere
`main()` calls `Classifier.load()` **once** and passes the `Future` to `TmClassifierApp`.
While it loads, the Welcome screen shows a progress bar and a disabled "Loading model…" button.
Our choice: **constructor injection**. The ready `Classifier` is passed to `MainShell` → `HomeScreen`,
`ModelScreen`, and its labels to `HistoryScreen` / `ResultScreen`. It is explicit and easy to
trace, with no extra package, and three levels deep is still readable. No screen calls
`Classifier.load()`. `close()` runs from `AppLifecycleListener(onDetach)` and from the
root `State.dispose()`. It is guarded, so a second call is harmless.

### T12 Fail politely
- **Text file:** Model tab → *Robustness check* → "Classify a text file" sends the bytes of
  `labels.txt` to `classify`. Result: a red banner reading *"Handled: This file is not a readable image
  (JPEG, PNG, GIF, WebP or BMP)."* No red screen, no frozen spinner. The same message appears on
  Home for any non-image (e.g. a download whose server lies about the content type).
- **Typo in the model path:** `flutter run --dart-define=MODEL_PATH=assets/model/model_unqant.tflite`.
  The start-up screen shows *"The model could not be loaded …"* and *"Expected at:
  assets/model/model_unqant.tflite"* plus the underlying error.

### T13 Tests (`flutter test`)
`test/labels_test.dart` contains the normal case, the awkward case (`\r\n`, a trailing blank line,
`2 Car keys`), our own `labels.txt`, a label starting with a digit, and an empty file.
`test/preprocess_test.dart` checks the tensor shape, the −1…1 mapping, that a text file gives a `FormatException`,
and that grayscale/alpha images become RGB. **9 tests, all pass.**
The awkward test did **not** expose a bug in the sample `parseLabels`. `trim()` already removes the `\r`,
blank lines are skipped, and the regex `^\d+\s+` removes only the leading index, so spaces inside a label survive.

### Q: Normalisation `value / 255` instead of `value / 127.5 − 1`: what happens, why no crash?
The inputs then lie in 0…1 instead of −1…1. To the network every picture looks like a washed-out,
low-contrast, over-bright version of itself. The percentages shift and the model becomes less sure or
wrong, while still looking confident. Example: our synthetic test image went from
phone 96.6 / bokal 0.9 to phone 94.5 / bokal 3.5. /255: ______.
Nothing crashes because the tensor still has the **same shape and type** (`float32 [1,224,224,3]`).
The interpreter checks only that, never the value range, and the softmax still sums to 1.
That is why this bug is dangerous: you only see it as bad predictions.

### Q: Where is the number of classes written down? What changes for a seventh class?
Nowhere in Dart code. It comes from `labels.txt` (`labels.length`). Output buffer, rows on
the Result screen, chips on Welcome and the Model screen are all built from that list. `load()` cross-checks
it with the model's output tensor `[1, N]`. After retraining with a 7th class you replace **only the two
files** in `assets/model/` (and update this class list and the evaluation). No code edits. If only one
file is replaced, the app stops at start-up with "labels.txt has 6 lines but the model outputs 7 classes".

---

## Part 4: Five screens, one design

### T14 Design credit
- **Design:** Material 3 Design Kit
- **Author:** Material Design (Google)
- **Link:** https://www.figma.com/community/file/1035203688168086460
- **Licence:** CC BY 4.0 (Figma Community licence)
- Also shown in the app: Model tab → *Design credit*.
- Reference frames: `docs/design-1.png` `docs/design-2.png` 
### T15 Theme
`lib/theme/app_theme.dart` is the single place for colours (baseline M3 light scheme: primary `#6750A4`,
secondary `#625B71`, tertiary `#7D5260`, surface `#FEF7FF`, error `#B3261E`), the type scale (Roboto,
M3 sizes and line heights), the shape scale (8 / 12 / 16 / 28 dp, stadium buttons), the 4 dp spacing grid and the
component themes (AppBar, Card, Filled/Outlined/Text buttons, Chip, NavigationBar, ListTile, Dialog,
SnackBar, Divider). Screens use `Theme.of(context)` only. There is no `Color(0xFF…)` and no font size outside the theme file.

### T16 / T17 Screens and navigation
| # | Screen | File | Contains |
|---|---|---|---|
| 1 | Welcome | `welcome_screen.dart` | App name, one sentence, the 6 classes as chips, *Get started*; loading state and start-up error state |
| 2 | Home | `home_screen.dart` | *Take a photo* / *Choose from gallery* / *Download an image* as separate cards, latest result, busy and error states |
| 3 | Result | `result_screen.dart` | Centred image (`BoxFit.contain`, ≤ 45 % of screen height), one row per label, sorted, top row emphasised, sum, source, timing, evaluation picker |
| 4 | History | `history_screen.dart` | Newest first: thumbnail, top label, %, source icon, time; designed empty state; copy evaluation table |
| 5 | Model | `model_screen.dart` | Labels, number of classes, input size and tensor shapes, file name, robustness check, design credit |

A `NavigationBar` switches Home / History / Model, and Result is pushed. System back on History/Model goes to Home
first. All screens are scrollable, text has 16 dp side margins, every tappable element has an ink ripple or
pressed state, and loading, empty and error states are designed.

### Q: Two things from the Figma design we changed or left out, and why
1. **Dynamic colour and the dark theme are left out.** The kit ships light and dark schemes and is built for the Theme Builder.
   We implemented only the baseline light scheme, so everything is in one theme and one set of screens to check on a small phone.
   Dark mode would double the visual QA for no lab points.
2. **No FAB and no medium/large collapsing top app bars.** The kit's typical layout puts the main action in a FAB. The
   lab needs three equally important, clearly separated actions, so they became three full-width cards. The small
   top app bar keeps the image and the six rows on screen without scrolling.
3. (Bonus) **Roboto is not bundled.** It is the system font on Android. On iOS the app falls back to SF Pro instead of adding 1 MB of font files.

### Q: Does the Model screen read the labels from the classifier or from the file again?
**From the classifier** (`classifier.labels`). It is one source of truth: the screen shows exactly the list that index *i*
of the output tensor is paired with, so it can never disagree with what the Result screen uses. Reading
the file again would duplicate parsing and asset access, and it could show something different if
parsing or the file ever changed between the two reads. The file was already read once and validated against the model at start-up.

---

## Part 5: Three sources, one result

`lib/services/image_sources.dart`: `fromCamera()`, `fromGallery()` (both `maxWidth: 1024`, `null` =
cancelled) and `fromUrl(url)` (`http.get`, 15 s timeout). All three return `Uint8List`. One method,
`HomeScreen._classifyFrom`, runs bytes → `classify` → `HistoryStore.add` → push `ResultScreen`, whatever the source.

**T20 Download error handling**, each with its own message:

| Case | Message on screen |
|---|---|
| Not a URL / no `http(s)://` | "That is not a web address. It must start with http:// or https://" |
| Status ≠ 200 (e.g. 404) | "The server answered 404 instead of 200. Is the address right?" |
| Web page instead of picture | "That address is a "text/html; charset=utf-8" page, not an image. Copy the address of the image itself …" |
| No network / unknown host | "No connection. Check the internet and the address, then try again." |
| Timeout (15 s) | "The server did not answer within 15 seconds." |

Second route: save a picture from the phone browser (long-press → *Download image*) and pick it with
*Choose from gallery*. It appears as source **Gallery**.

**T21 Result:** see the table under Part 4. The percentage is `(confidence * 100).toStringAsFixed(1)` + `%`, and the sum shown under the rows is 100.0 %.
**T22 History:** every successful classification from any source. Tapping an entry reopens the Result from the stored
predictions. The model does **not** run again.

### T23 Evaluation table

How we filled it in: classify each picture, then on the Result screen tap the chip with what the picture
really shows. History → table icon copies the table below with accuracy and weakest class, built
from those real attempts. 

| # | Source | Expected | Predicted | % | Correct |
|---|--------|----------|-----------|---|---------|
| 1 | Camera | me | ✏️ | ✏️ | ✏️ |
| 2 | Gallery | me | | | |
| 3 | Download | me | | | |
| 4 | Camera | nothing | | | |
| 5 | Gallery | nothing | | | |
| 6 | Download | nothing | | | |
| 7 | Camera | phone | | | |
| 8 | Gallery | phone | | | |
| 9 | Download | phone | | | |
| 10 | Camera | bokal | | | |
| 11 | Gallery | bokal | | | |
| 12 | Download | bokal | | | |
| 13 | Camera | mouse | | | |
| 14 | Gallery | mouse | | | |
| 15 | Download | mouse | | | |
| 16 | Camera | notebook | | | |
| 17 | Gallery | notebook | | | |
| 18 | Download | notebook | | | |


### Q: The same object scored differently from the camera and from a downloaded picture. Two reasons from the training data
1. **Domain shift in how the pictures look.** All training samples are laptop-webcam frames from one lab: the same lens,
   low resolution, the same desk and wall, indoor light and white balance. Downloaded pictures are product or stock
   photos with studio lighting, white backgrounds, sharp focus and colour grading the model never saw.
   The phone camera is somewhere in between.
2. **Framing and context.** In training the object was held close, centred, filling the frame, often with our hands
   around it. Web pictures are often wide shots where the object is small or off-centre (the centre crop may cut it),
   or show a different model/colour of the object. With about 50 samples of *one* specific phone/glass/mouse, the model
   may have learned cues like our hands, our desk or one particular colour rather than "phone" in general.

### Q: `classify` runs on the UI thread. How long on our phone, and what does the user see?
Measured with `Stopwatch` inside `classify`. The Result screen and the smoke test show it.

During that time the UI thread is blocked. We first await `endOfFrame`, so the "Classifying…" card is
painted, but then its progress bar **freezes**, taps are ignored and nothing animates until the Result
screen appears. Most of the time is the pure-Dart pre-processing (decode + building 150 528 nested doubles), not
the network itself. `IsolateInterpreter` and/or a background isolate for decoding would fix it (stretch goal 3).

---

## Checkpoint questions

### 1. Trace one photo from the shutter button to the percentage on screen
1. **Shutter → JPEG file.** The OS camera app saves the photo. `image_picker` scales it to ≤ 1024 px wide and returns an `XFile`. *(image_sources.dart, `fromCamera`)*
2. **File → bytes.** `XFile.readAsBytes()` → `Uint8List`, the compressed JPEG bytes. *(image_sources.dart)*
3. **Bytes enter the one path.** `HomeScreen._classifyFrom` hands them to `Classifier.classify`. *(home_screen.dart)*
4. **Decode.** `findDecoderForData` → JPEG decoder → `img.Image`, then converted to 8-bit RGB. *(preprocess.dart, `decodeForModel`)*
5. **Orientation.** `bakeOrientation` applies the EXIF rotation to the pixels. *(preprocess.dart)*
6. **Crop + resize.** `copyResizeCropSquare(size: 224)`: centre square, box-averaged to 224×224. *(preprocess.dart, `toInputTensor`)*
7. **Normalise → tensor.** Each pixel `[r,g,b]` 0…255 → `v/127.5 − 1` → nested `List<double>` of shape `[1,224,224,3]`. *(preprocess.dart)*
8. **Inference.** `Interpreter.run` copies it into the float32 input tensor, runs the MobileNet graph and writes a softmax `[1,6]` into `output`. *(classifier.dart → tflite_flutter → native TFLite)*
9. **Pair + sort.** Index *i* ↔ `labels[i]` → `Prediction(label, confidence)`, sorted descending. *(classifier.dart)*
10. **Store.** `HistoryStore.add` → `HistoryEntry` with bytes, predictions, source and timing. *(history.dart)*
11. **Display.** `ResultScreen` → `PredictionRow`: `(confidence * 100).toStringAsFixed(1)` + `" %"` and the bar `value: confidence`. *(result_screen.dart, prediction_row.dart, `Prediction.percent`)*

### 2. Which three lines of `pubspec.yaml` would break the app if deleted, and what would the error be?
1. `    - assets/model/` → the files are not bundled. At start-up `Interpreter.fromAsset` throws
   *"Unable to load asset: assets/model/model_unquant.tflite"* and the Welcome screen shows our model-load error.
2. `  tflite_flutter: ^0.12.1` → compile error: *"Target of URI doesn't exist: 'package:tflite_flutter/tflite_flutter.dart'"*,
   *"Undefined class 'Interpreter'"*. The app does not build.
3. `  image_picker: ^1.2.0` → compile error: *"Target of URI doesn't exist: 'package:image_picker/image_picker.dart'"*,
   *"Undefined class 'ImagePicker'"* / *"Undefined name 'ImageSource'"*.
(The same holds for `image:` and `http:`. Deleting `uses-material-design: true` would not break the build, but every `Icons.*` would render as an empty box.)

### 3. Why must the pre-processing in Flutter match what Teachable Machine did? Name the two things.
The weights were learned for one specific input distribution. The network has no idea what a "picture" is, only what
numbers it saw in training. Feed it differently prepared numbers and it still answers, with confident nonsense,
and no error tells you (see the /255 experiment). The two things that must match:
1. **Geometry:** the same **centre square crop resized to 224 × 224** (with the photo upright, hence `bakeOrientation`), so objects have the framing and scale seen in training.
2. **Pixel values:** the same **normalisation**, RGB channel order with `value / 127.5 − 1` → −1…1 for the float model.

### 4. The model is 97 % sure that a shoe is a mug. Is that a bug? What does the percentage mean?
**Not a code bug.** It is how the model works. The output is a softmax over *our six classes only*. 97 % means
"compared to my other five options, this looks most like a mug". It is a relative score among known classes, after
softmax sharpening. It does **not** mean "97 % probability that this is a mug in the real world", and it is not a calibrated
measure of being right. The model has no way to say "none of these" (unless that is a trained class).
Our own test: a random-noise image was "phone 96.6 %". Mitigations: a broader background/"other" class with many random objects,
a confidence threshold ("not sure" below e.g. 80 %), and more varied training data.

### 5. What stays on the device and what leaves it? Compare with a cloud vision API.
**Stays on the device:** the model and labels (inside the app), every photo, decoding, pre-processing, inference, the results
and the history. History is only in memory and is gone when the app closes. No analytics, no upload.
**Leaves the device:** only for *Download an image*. An HTTP GET goes to the server of that URL, which learns our IP address,
the time and which image was requested. The image comes *down*, nothing goes *up*. Camera and gallery work in flight mode.
**Cloud vision API:** the photo itself is uploaded to a third party. That includes faces (our `me` class), the background of our room
and possibly EXIF location. It needs a network, adds about 0.5–2 s of latency, costs money per request and needs consent and a privacy policy.
In exchange you get much larger models, thousands of classes, no model in the app and server-side updates without a new release.
