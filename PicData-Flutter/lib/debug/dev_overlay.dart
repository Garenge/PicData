import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Debug-only right-top "Dev" floating overlay.
///
/// - Uses `IgnorePointer` so it never blocks page interactions.
/// - Intended to replace Flutter's default `DEBUG` banner.
class DevDebugOverlay extends StatelessWidget {
  const DevDebugOverlay({
    super.key,
    this.text = 'dev',
    this.opacity = 0.6,
    this.top = 0,
    this.right = 0,
  });

  final String text;
  final double opacity;
  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    // Use the app's bottom navigation height as the triangle side length.
    const double size = kBottomNavigationBarHeight;
    final double fontSize = size / 5.5;

    return Positioned(
      top: top,
      right: right,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: ClipPath(
            clipper: _TopRightTriangleClipper(),
            child: SizedBox(
              width: size,
              height: size,
              child: Container(
                color: Colors.black87,
                alignment: Alignment.center,
                child: Transform.rotate(
                  // Text along the diagonal.
                  angle: math.pi / 4,
                  child: Transform.translate(
                    // Nudge text back into the clipped triangle area.
                    offset: Offset(size * 0.15, -size * 0.15),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRightTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Triangle in the top-right corner, with a diagonal from top-left to bottom-right.
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _TopRightTriangleClipper oldClipper) => false;
}

