import 'package:flutter/material.dart';

enum RouteArrowDirection {
  left,
  right,
  straight,
  uTurn,
}

class NavigationRouteArrow extends StatelessWidget {
  final RouteArrowDirection direction;
  final double size;

  const NavigationRouteArrow({
    super.key,
    required this.direction,
    this.size = 56,
  });

  IconData get _icon {
    switch (direction) {
      case RouteArrowDirection.left:
        return Icons.turn_left_rounded;
      case RouteArrowDirection.right:
        return Icons.turn_right_rounded;
      case RouteArrowDirection.straight:
        return Icons.straight_rounded;
      case RouteArrowDirection.uTurn:
        return Icons.u_turn_left_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF168A61),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          _icon,
          color: Colors.white,
          size: size * 0.65,
        ),
      ),
    );
  }
}
