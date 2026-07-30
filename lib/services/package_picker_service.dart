import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import 'platform_capabilities.dart';

class PackagePickerService {
  static const _channel = MethodChannel('com.sorgunemlak.defter/file_picker');

  Future<String?> pickPackage() async {
    if (PlatformCapabilitiesScope.current.isDesktop) {
      const typeGroup = XTypeGroup(
        label: 'Sorgun Emlak Defteri paketi',
        extensions: ['sedef'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      return file?.path;
    }
    return _channel.invokeMethod<String>('pickSedefPackage');
  }

  Future<String?> savePackage({
    required File source,
    required String suggestedName,
  }) async {
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) {
      return null;
    }
    final destination = File(location.path);
    await destination.parent.create(recursive: true);
    await source.copy(destination.path);
    return destination.path;
  }
}
