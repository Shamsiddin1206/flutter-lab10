/// Image -> tensor pre-processing. Pure Dart (package:image only), so it runs
/// in a plain unit test without a phone.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decodes phone image bytes into an 8-bit RGB image with EXIF rotation applied.
///
/// Only formats with a real signature ("magic bytes") are accepted.
/// `img.decodeImage` alone would also try TGA, which has no signature: the bytes
/// of a text file then "look like" a TGA header and the decoder throws or
/// returns noise.
///
/// Throws [FormatException] if the bytes are not a readable image.
img.Image decodeForModel(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final known =
      decoder is img.JpegDecoder ||
      decoder is img.PngDecoder ||
      decoder is img.GifDecoder ||
      decoder is img.WebPDecoder ||
      decoder is img.BmpDecoder;

  img.Image? decoded;
  if (decoder != null && known) {
    try {
      decoded = decoder.decode(bytes, frame: 0);
    } catch (_) {
      decoded = null; // corrupt or truncated file
    }
  }
  if (decoded == null) {
    throw const FormatException(
      'This file is not a readable image (JPEG, PNG, GIF, WebP or BMP).',
    );
  }

  // Grayscale, palette, alpha or 16-bit images -> plain 8-bit RGB.
  if (decoded.numChannels != 3 ||
      decoded.format != img.Format.uint8 ||
      decoded.hasPalette) {
    decoded = decoded.convert(format: img.Format.uint8, numChannels: 3);
  }
  // Phone cameras store rotation in EXIF instead of rotating the pixels.
  return img.bakeOrientation(decoded);
}

/// Same crop as Teachable Machine used for training: centre square, resized
/// to [size] x [size]. Then every channel 0..255 -> -1..1 (value / 127.5 - 1).
///
/// Result shape: [1, size, size, 3].
List<List<List<List<double>>>> toInputTensor(img.Image image, int size) {
  final square = img.copyResizeCropSquare(
    image,
    size: size,
    // Box-average downscaling, closer to the browser canvas resize Teachable
    // Machine used than the default nearest-neighbour (which aliases).
    interpolation: img.Interpolation.average,
  );
  return [
    List.generate(
      size,
      (y) => List.generate(size, (x) {
        final p = square.getPixel(x, y);
        return [p.r / 127.5 - 1, p.g / 127.5 - 1, p.b / 127.5 - 1];
      }),
    ),
  ];
}
