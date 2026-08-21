import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final String ratting; // بدون تغییر در نام متغیر برای حفظ اتصال با دیتابیس

  const RatingStars({super.key, required this.ratting});

  @override
  Widget build(BuildContext context) {
    // تبدیل رشته به double برای پشتیبانی از امتیازهای اعشاری
    double ratingValue = double.tryParse(ratting) ?? 0.0;

    // اطمینان از قرار داشتن امتیاز بین 0 و 5
    if (ratingValue > 5) ratingValue = 5.0;
    if (ratingValue < 0) ratingValue = 0.0;

    return Directionality(
      textDirection: Directionality.of(context), // تنظیم هوشمند جهت ستاره‌ها متناسب با زبان فعال
      child: Row(
        mainAxisSize: MainAxisSize.min, // جمع شدن جهت جلوگیری از کشیدگی افقی
        children: <Widget>[
          // نمایش ۵ ستاره بر اساس مقدار امتیاز راننده
          for (int i = 1; i <= 5; i++)
            Icon(
              i <= ratingValue 
                  ? Icons.star_rounded // استفاده از آیکون‌های گردتر و مدرن‌تر فلاتر
                  : (i - 0.5 <= ratingValue ? Icons.star_half_rounded : Icons.star_border_rounded),
              color: i <= ratingValue || i - 0.5 <= ratingValue 
                  ? Colors.amber // رنگ طلایی برای ستاره‌های فعال
                  : Colors.grey.shade300, // خاکستری برای ستاره‌های خالی
              size: 20,
            ),
        ],
      ),
    );
  }
}