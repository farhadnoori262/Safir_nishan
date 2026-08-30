import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../controllers/navigation_controller.dart';
import '../../../utils/app_colors.dart';

class NavigationTurnBanner extends StatelessWidget {
  final NavigationController controller;
  final VoidCallback onStopNavigation;

  const NavigationTurnBanner({
    super.key,
    required this.controller,
    required this.onStopNavigation,
  });

  String _distanceText() {
    final meters = controller.distanceToNextTurn;

    if (meters >= 1000) {
      final kilometers = meters / 1000;
      return '${kilometers.toStringAsFixed(1)} ${'kilometers'.tr()}';
    }

    return '$meters ${'meters'.tr()}';
  }

  String _streetText() {
    if (controller.currentStreet.isNotEmpty) {
      return controller.currentStreet;
    }

    if (controller.navigationInstruction.isNotEmpty) {
      return controller.navigationInstruction;
    }

    return 'route_preparing'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 18,
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: AppColors.primaryBrand,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    controller.currentTurnIcon,
                    color: AppColors.buttonText,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _distanceText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.buttonText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _streetText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: ui.TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppColors.buttonText.withOpacity(0.92),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: controller.isVoiceEnabled
                      ? 'خاموش کردن راهنمای صوتی'
                      : 'روشن کردن راهنمای صوتی',
                  onPressed: controller.toggleVoice,
                  icon: Icon(
                    controller.isVoiceEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: AppColors.buttonText,
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
