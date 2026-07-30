import 'package:flutter/material.dart';

class ResponsiveWidth extends StatelessWidget {
  const ResponsiveWidth({
    super.key,
    required this.child,
    this.maxWidth = 1500,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
