// lib/widgets/animated_background.dart

import 'package:flutter/material.dart';
import 'package:animated_background/animated_background.dart';

class DreamyBackground extends StatelessWidget {
  final Widget child;
  final TickerProvider vsync; // <-- ADD THIS

  const DreamyBackground({
    super.key,
    required this.child,
    required this.vsync, // <-- ADD THIS
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      behaviour: RandomParticleBehaviour(
        options: const ParticleOptions(
          baseColor: Colors.white,
          spawnMinSpeed: 10.0,
          spawnMaxSpeed: 30.0,
          particleCount: 50,
          spawnMinRadius: 1.0,
          spawnMaxRadius: 2.5,
        ),
      ),
      vsync: vsync, // <-- CHANGE THIS from VSyncProvider.of(context)
      child: child,
    );
  }
}
