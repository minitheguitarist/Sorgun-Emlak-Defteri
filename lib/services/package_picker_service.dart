import 'package:flutter/services.dart';

class PackagePickerService {
  static const _channel = MethodChannel('com.sorgunemlak.defter/file_picker');

  Future<String?> pickPackage() {
    return _channel.invokeMethod<String>('pickSedefPackage');
  }
}
