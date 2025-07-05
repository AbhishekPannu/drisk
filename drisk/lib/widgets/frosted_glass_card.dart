import 'dart:ui';
import 'package:flutter/material.dart';

class FrostedGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius? borderRadius;

  const FrostedGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.symmetric(vertical: 8.0),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          margin: margin,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: borderRadius ?? BorderRadius.circular(20.0),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
