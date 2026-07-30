import 'package:flutter/material.dart';

import '../services/platform_capabilities.dart';

class PlatformLockedAction extends StatelessWidget {
  const PlatformLockedAction({
    super.key,
    required this.label,
    this.expanded = false,
  });

  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.lock_outline),
      label: Text(label),
    );
    final child =
        expanded ? SizedBox(width: double.infinity, child: button) : button;
    return Tooltip(
      message: PlatformCapabilitiesScope.phoneOnlyMessage,
      waitDuration: const Duration(milliseconds: 350),
      child: MouseRegion(cursor: SystemMouseCursors.forbidden, child: child),
    );
  }
}
