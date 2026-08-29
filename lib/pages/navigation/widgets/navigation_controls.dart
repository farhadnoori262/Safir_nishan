import 'package:flutter/material.dart';

class NavigationControls extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onMyLocation;
  final VoidCallback onShowRoute;
  final VoidCallback onToggleMute;
  final VoidCallback onExit;

  const NavigationControls({
    super.key,
    required this.isMuted,
    required this.onMyLocation,
    required this.onShowRoute,
    required this.onToggleMute,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(
          tooltip: 'موقعیت من',
          icon: Icons.my_location_rounded,
          onPressed: onMyLocation,
        ),
        const SizedBox(height: 10),
        _MapControlButton(
          tooltip: 'نمایش کل مسیر',
          icon: Icons.alt_route_rounded,
          onPressed: onShowRoute,
        ),
        const SizedBox(height: 10),
        _MapControlButton(
          tooltip: isMuted ? 'روشن کردن صدا' : 'قطع کردن صدا',
          icon: isMuted
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          onPressed: onToggleMute,
        ),
        const SizedBox(height: 10),
        _MapControlButton(
          tooltip: 'خروج از مسیریابی',
          icon: Icons.close_rounded,
          iconColor: const Color(0xFFE53935),
          onPressed: onExit,
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
