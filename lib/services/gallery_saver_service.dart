import 'package:flutter/services.dart';

class GallerySaverService {
  const GallerySaverService();

  static const _channel = MethodChannel('com.sorgunemlak.defter/gallery_saver');

  Future<String?> savePng({
    required Uint8List bytes,
    required String fileName,
  }) {
    return _channel.invokeMethod<String>('saveAdvertisementPng', {
      'bytes': bytes,
      'fileName': fileName,
    });
  }
}
