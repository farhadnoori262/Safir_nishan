import 'package:flutter/material.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

class PaymentDialog extends StatefulWidget {
  final String fareAmount;

  const PaymentDialog({
    super.key,
    required this.fareAmount,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  CommonMethods cMethods = CommonMethods();

  // 🎨 ثوابت پالت رنگی رسمی سفیر
  static const Color brandPrimary = Color(0xFF145A41);
  static const Color btnPrimary = Color(0xFF1B7A57);
  static const Color btnPressed = Color(0xFF0F4A35);
  static const Color cardBgLight = Color(0xFFEAF6F1);
  static const Color textOnBtn = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final String currencyUnit = tr(context, 'currency_unit');
    
    final String paymentGuideMsg = tr(context, 'msg_payment_guide')
        .replaceAll('{amount}', widget.fareAmount)
        .replaceAll('{currency}', currencyUnit);

    return Directionality(
      textDirection: Directionality.of(context),
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: cardBgLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: brandPrimary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                tr(context, 'title_collect_cash'),
                style: const TextStyle(
                  fontFamily: 'IranYekan',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade200),
              const SizedBox(height: 20),
              
              // نمایش بزرگ و برجسته مبلغ کرایه
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: cardBgLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    "${widget.fareAmount} $currencyUnit",
                    style: const TextStyle(
                      fontFamily: 'IranYekan',
                      color: brandPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                paymentGuideMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IranYekan',
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // بستن دیالوگ پرداخت
                    Navigator.pop(context); // خروج از صفحه NewTripPage
                    cMethods.turnOnLocationUpdatesForHomePage();
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return btnPressed;
                      }
                      return btnPrimary;
                    }),
                    elevation: WidgetStateProperty.all(0),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  child: Text(
                    tr(context, 'btn_cash_received'),
                    style: const TextStyle(
                      fontFamily: 'IranYekan',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textOnBtn,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
