import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class NavigationBannerWidget extends StatelessWidget {
  final String modifier;
  final String nextStreet;
  final double distanceToNext;
  final VoidCallback onMuteToggle;
  final bool isMuted;
  final VoidCallback? onClose;

  const NavigationBannerWidget({
    super.key,
    required this.modifier,
    required this.nextStreet,
    required this.distanceToNext,
    required this.onMuteToggle,
    required this.isMuted,
    this.onClose,
  });

  IconData _turnIcon(String value) {
    switch (value.toLowerCase()) {
      case 'right':
        return Icons.turn_right_rounded;
      case 'slight right':
        return Icons.turn_slight_right_rounded;
      case 'sharp right':
        return Icons.turn_sharp_right_rounded;
      case 'left':
        return Icons.turn_left_rounded;
      case 'slight left':
        return Icons.turn_slight_left_rounded;
      case 'sharp left':
        return Icons.turn_sharp_left_rounded;
      case 'uturn':
        return Icons.u_turn_left_rounded;
      default:
        return Icons.straight_rounded;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} ${'km'.tr()}';
    }

    return '${meters.ceil()} ${'meters'.tr()}';
  }

  String _instructionText() {
    final street = nextStreet.trim();

    if (street.isEmpty) {
      return 'continue_straight'.tr();
    }

    final translated = 'enter_street'.tr(
      args: [street],
    );

    return translated == 'enter_street'
        ? street
        : translated;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              12,
              12,
              8,
              12,
            ),
            decoration: BoxDecoration(
              color: SafirColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.26),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _turnIcon(modifier),
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDistance(distanceToNext),
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _instructionText(),
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isMuted
                      ? 'فعال‌کردن صدا'
                      : 'قطع صدا',
                  onPressed: onMuteToggle,
                  icon: Icon(
                    isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    tooltip: 'پایان مسیریابی',
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
