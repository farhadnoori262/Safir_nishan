# حفظ کلاس‌های ورود گوگل و فایربیس
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# جلوگیری از خراب شدن نام کلاس‌های فلاتر و پلاگین‌ها
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class com.google.auth.** { *; }
