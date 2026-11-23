import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tm_classifier/services/preprocess.dart';

Uint8List _png(int w, int h, img.Color c) => img.encodePng(
  img.fill(
    img.Image(width: w, height: h),
    color: c,
  ),
);

void main() {
  test('tensor has shape [1, 224, 224, 3] for a non-square picture', () {
    final t = toInputTensor(
      decodeForModel(_png(300, 200, img.ColorRgb8(10, 20, 30))),
      224,
    );
    expect(t.length, 1);
    expect(t[0].length, 224);
    expect(t[0][0].length, 224);
    expect(t[0][0][0].length, 3);
  });

  test('0..255 is mapped to -1..1', () {
    final white = toInputTensor(
      decodeForModel(_png(50, 50, img.ColorRgb8(255, 255, 255))),
      224,
    );
    final black = toInputTensor(
      decodeForModel(_png(50, 50, img.ColorRgb8(0, 0, 0))),
      224,
    );
    expect(white[0][100][100], everyElement(closeTo(1.0, 1e-6)));
    expect(black[0][100][100], everyElement(closeTo(-1.0, 1e-6)));
  });

  test('a text file is rejected with a FormatException, not a crash', () {
    final text = Uint8List.fromList(utf8.encode('0 me\n1 nothing\n2 phone\n'));
    expect(() => decodeForModel(text), throwsFormatException);
  });

  test('grayscale and alpha images become 3-channel RGB', () {
    final gray = img.Image(width: 10, height: 10, numChannels: 1);
    final rgba = img.Image(width: 10, height: 10, numChannels: 4);
    expect(decodeForModel(img.encodePng(gray)).numChannels, 3);
    expect(decodeForModel(img.encodePng(rgba)).numChannels, 3);
  });
}
