import 'package:flutter/foundation.dart';

class PlatformCapabilities {
  const PlatformCapabilities({
    required this.isDesktop,
    required this.supportsCamera,
    required this.supportsContactPicker,
    required this.supportsLocationEditing,
    required this.supportsGallerySave,
    required this.supportsDirectCall,
    required this.supportsNativeShare,
  });

  factory PlatformCapabilities.current() {
    final desktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return PlatformCapabilities(
      isDesktop: desktop,
      supportsCamera: android,
      supportsContactPicker: android,
      supportsLocationEditing: android,
      supportsGallerySave: android,
      supportsDirectCall: android,
      supportsNativeShare: android,
    );
  }

  static const android = PlatformCapabilities(
    isDesktop: false,
    supportsCamera: true,
    supportsContactPicker: true,
    supportsLocationEditing: true,
    supportsGallerySave: true,
    supportsDirectCall: true,
    supportsNativeShare: true,
  );

  static const desktop = PlatformCapabilities(
    isDesktop: true,
    supportsCamera: false,
    supportsContactPicker: false,
    supportsLocationEditing: false,
    supportsGallerySave: false,
    supportsDirectCall: false,
    supportsNativeShare: false,
  );

  final bool isDesktop;
  final bool supportsCamera;
  final bool supportsContactPicker;
  final bool supportsLocationEditing;
  final bool supportsGallerySave;
  final bool supportsDirectCall;
  final bool supportsNativeShare;
}

class PlatformCapabilitiesScope {
  PlatformCapabilitiesScope._();

  static PlatformCapabilities current = PlatformCapabilities.current();

  static const phoneOnlyMessage =
      'Bu özellik yalnızca telefon sürümünde kullanılabilir.';
}
