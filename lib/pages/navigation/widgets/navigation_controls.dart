import 'package:flutter/material.dart';

class NavigationControls extends StatelessWidget {
  final bool isNavigating;
  final VoidCallback onResetNorth;
  final VoidCallback onShowFullRoute;
  final VoidCallback onGoToStart;
  final VoidCallback onMyLocation;

  const NavigationControls({
    super.key,
    required this.isNavigating,
    required this.onResetNorth,
    required this.onShowFullRoute,
    required this.onGoToStart,
    required this.onMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(
          tooltip: 'شمال',
          icon: Icons.navigation_rounded,
          iconColor: Colors.redAccent,
          onPressed: onResetNorth,
        ),
        const SizedBox(height: 10),
        if (isNavigating) ...[
          _MapControlButton(
            tooltip: 'نمایش کل مسیر',
            icon: Icons.alt_route_rounded,
            onPressed: onShowFullRoute,
          ),
          const SizedBox(height: 10),
          _MapControlButton(
            tooltip: 'بازگشت به آغاز مسیر',
            icon: Icons.home_outlined,
            onPressed: onGoToStart,
          ),
          const SizedBox(height: 10),
        ],
        _MapControlButton(
          tooltip: 'موقعیت من',
          icon: Icons.my_location_rounded,
          iconColor: const Color(0xFF168A61),
          onPressed: onMyLocation,
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onPressed;

  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: iconColor ?? const Color(0xFF202124),
        ),
      ),
    );
  }
}
