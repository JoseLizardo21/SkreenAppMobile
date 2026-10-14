import 'package:flutter/material.dart';

/// Smooth fade + subtle scale transition between screens.
class FadeScalePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeScalePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);

    // Outgoing screen fades back slightly while the new one fades/scales in
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.6).animate(exit),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.98).animate(exit),
        child: FadeTransition(
          opacity: enter,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(enter),
            child: child,
          ),
        ),
      ),
    );
  }
}
