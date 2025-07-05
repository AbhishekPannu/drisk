import 'package:flutter/material.dart';
import 'package:animated_background/animated_background.dart';

class DreamyBackground extends StatelessWidget {
  final Widget child;
  final TickerProvider vsync;

  const DreamyBackground({
    super.key,
    required this.child,
    required this.vsync,
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
      vsync: vsync,
      child: child,
    );
  }
}
