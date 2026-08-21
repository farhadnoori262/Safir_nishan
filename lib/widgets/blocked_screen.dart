import 'package:flutter/material.dart';
import 'package:safir_drivers/pages/auth/register_screen.dart'; 
import 'package:safir_drivers/utils/lang_helper.dart';

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // آیکون هشدار مسدودیت
                const Icon(
                  Icons.block_rounded,
                  color: Color(0xFFD32F2F),
                  size: 80,
                ),
                const SizedBox(height: 24),
                
                // متن اطلاع‌رسانی مسدودیت
                Text(
                  tr(context, 'account_blocked_msg'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'IranYekan',
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                
                // ایمیل پشتیبانی
                const Text(
                  "farhadnoori442@gmail.com",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 32),
                
                // دکمه تایید و بازگشت به صفحه ثبت‌نام
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F), // رنگ قرمز هشدار
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      tr(context, 'btn_got_it'),
                      style: const TextStyle(
                        fontFamily: 'IranYekan',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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