import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  final String messageText;
  const LoadingDialog({super.key, required this.messageText});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Directionality(
          textDirection: Directionality.of(context), // تنظیم داینامیک جهت متن متناسب با زبان سیستم
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF145A41)), // سبز سفیر
                strokeWidth: 3,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  messageText,
                  style: const TextStyle(
                    fontFamily: 'IranYekan',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}