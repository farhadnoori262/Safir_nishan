import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';

class NavigationControls extends StatelessWidget {
  final bool navigationStarted;
  final VoidCallback onResetToNorth;
  final VoidCallback onShowFullRoute;
  final VoidCallback onGoToStart;
  final VoidCallback onFollowLocation;

  const NavigationControls({
    super.key,
    required this.navigationStarted,
    required this.onResetToNorth,
    required this.onShowFullRoute,
    required this.onGoToStart,
    required this.onFollowLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 14,
      bottom: navigationStarted ? 132 : 290,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapActionButton(
              icon: Icons.navigation_rounded,
              tooltip: 'align_to_north'.tr(),
              iconColor: Colors.redAccent,
              onPressed: onResetToNorth,
            ),
            const SizedBox(height: 10),
            if (navigationStarted) ...[
              _MapActionButton(
                icon: Icons.alt_route_rounded,
                tooltip: 'show_full_route'.tr(),
                onPressed: onShowFullRoute,
              ),
              const SizedBox(height: 10),
              _MapActionButton(
                icon: Icons.home_outlined,
                tooltip: 'back_to_start'.tr(),
                onPressed: onGoToStart,
              ),
              const SizedBox(height: 10),
            ],
            _MapActionButton(
              icon: Icons.my_location_rounded,
              tooltip: 'my_location'.tr(),
              iconColor: AppColors.primaryButton,
              onPressed: onFollowLocation,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;

  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black38,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        splashRadius: 24, // اندازه افکت فشردن دکمه
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: iconColor ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}
