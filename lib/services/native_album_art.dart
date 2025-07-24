import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeAlbumArt {
  static const MethodChannel _channel = MethodChannel('native_album_art');

  static Future<Uint8List?> getAlbumArt(String filePath) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('getAlbumArt', {
        'filePath': filePath,
      });
      return result;
    } catch (e) {
      return null;
    }
  }
}
