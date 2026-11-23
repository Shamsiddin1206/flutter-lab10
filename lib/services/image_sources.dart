import 'dart:async';
import 'dart:io' show SocketException;
import 'dart:typed_data';

// ignore: deprecated_member_use
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Where a picture came from. Shown on the Result and History screens.
enum ImageSourceKind {
  camera('Camera', Icons.photo_camera_outlined),
  gallery('Gallery', Icons.photo_library_outlined),
  download('Download', Icons.cloud_download_outlined),
  sample('Sample', Icons.science_outlined);

  const ImageSourceKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A download failed for a reason the user can understand and fix.
class DownloadException implements Exception {
  const DownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Camera, gallery and download differ only in how the bytes arrive.
/// Every method returns raw bytes; no file path leaves this class.
class ImageSources {
  ImageSources({ImagePicker? picker, http.Client? client})
    : _picker = picker ?? ImagePicker(),
      _client = client ?? http.Client();

  final ImagePicker _picker;
  final http.Client _client;

  static const timeout = Duration(seconds: 15);

  /// The phone's own camera screen. `null` means the user cancelled.
  Future<Uint8List?> fromCamera() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024, // the model only sees 224x224; don't decode 12 MP
    );
    return shot == null ? null : await shot.readAsBytes();
  }

  /// The phone's gallery / photo picker. `null` means the user cancelled.
  Future<Uint8List?> fromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
    );
    return picked == null ? null : await picked.readAsBytes();
  }

  /// Downloads an image. Accepts the response only when the status is 200 and
  /// the content-type starts with `image/`. Every failure becomes a
  /// [DownloadException] with a readable message.
  Future<Uint8List> fromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw const DownloadException(
        'That is not a web address. It must start with http:// or https://',
      );
    }

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw DownloadException(
        'The server did not answer within ${timeout.inSeconds} seconds.',
      );
    } on SocketException {
      throw const DownloadException(
        'No connection. Check the internet and the address, then try again.',
      );
    } on http.ClientException catch (e) {
      throw DownloadException('The download failed: ${e.message}');
    }

    if (response.statusCode != 200) {
      throw DownloadException(
        'The server answered ${response.statusCode} instead of 200. '
        'Is the address right?',
      );
    }
    final type = response.headers['content-type'] ?? '';
    if (!type.toLowerCase().startsWith('image/')) {
      throw DownloadException(
        'That address is ${type.isEmpty ? 'not a picture' : 'a "$type" page'}, '
        'not an image. Copy the address of the image itself '
        '(long-press the picture → Copy image address).',
      );
    }
    return response.bodyBytes;
  }

  void dispose() => _client.close();
}
