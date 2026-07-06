import 'dart:ui';

import 'package:flutter/material.dart';

class TabSurface extends StatelessWidget {
  const TabSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 28,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xF2131C31), Color(0xEA0B1224)],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x66000612),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
