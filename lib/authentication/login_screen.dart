import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:safir_drivers/pages/dashboard.dart'; 
import '../methods/common_method.dart';
import '../widgets/loading_dialog.dart';
import '../utils/lang_helper.dart'; // 👈 اضافه شدن هیلپر ترجمه سه‌زبانه
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();
  CommonMethods cMethods = CommonMethods();

  checkIfNetworkIsAvailable() {
    //cMethods.checkConnectivity(context);
    signInFormValidation();
  }

  signInFormValidation() {
    if (!emailTextEditingController.text.contains("@")) {
      cMethods.displaySnackBar(tr(context, 'invalid_email_error'), context); // 👈 سه‌زبانه کردن پیام خطا
    } else if (passwordTextEditingController.text.trim().length < 6) { // اصلاح منطق به ۶ کاراکتر مطابق پیام متن
      cMethods.displaySnackBar(tr(context, 'password_length_error'), context); // 👈 سه‌زبانه کردن پیام خطا
    } else {
      signInUser();
    }
  }

  signInUser() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => LoadingDialog(messageText: tr(context, 'logging_in')), // 👈 متغیر داینامیک لودینگ
    );

    final User? userFirebase = (await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: emailTextEditingController.text.trim(),
          password: passwordTextEditingController.text.trim(),
        )
            .catchError((errorMsg) {
      Navigator.pop(context);
      cMethods.displaySnackBar(errorMsg.toString(), context);
    }))
        .user;

    if (!context.mounted) return;
    Navigator.pop(context);

    if (userFirebase != null) {
      DatabaseReference usersRef = FirebaseDatabase.instance.ref().child("drivers").child(userFirebase.uid);
      usersRef.once().then((snap) {
        if (snap.snapshot.value != null) {
          if ((snap.snapshot.value as Map)["blockStatus"] == "no") {
            Navigator.push(context, MaterialPageRoute(builder: (c) => Dashboard()));
          } else {
            FirebaseAuth.instance.signOut();
            cMethods.displaySnackBar(tr(context, 'blocked_account_error'), context); // 👈 سه‌زبانه کردن پیام مسدودی
          }
        } else {
          FirebaseAuth.instance.signOut();
          cMethods.displaySnackBar(tr(context, 'no_driver_record'), context); // 👈 سه‌زبانه کردن پیام عدم وجود راننده
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // تصویر خودروی سفیر
              Image.asset(
                "assets/images/uberexec.png",
                width: 220,
              ),

              const SizedBox(height: 30),

              Text(
                tr(context, 'driver_login_title'), // 👈 تیتر سه‌زبانه صفحه ورود
                style: const TextStyle(
                  fontFamily: 'IranYekan',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    TextField(
                      controller: emailTextEditingController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: tr(context, 'your_email'), // 👈 لیبل ایمیل
                        labelStyle: const TextStyle(
                          fontFamily: 'IranYekan',
                          fontSize: 14,
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 22),

                    TextField(
                      controller: passwordTextEditingController,
                      obscureText: true,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: tr(context, 'password'), // 👈 لیبل پسورد
                        labelStyle: const TextStyle(
                          fontFamily: 'IranYekan',
                          fontSize: 14,
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: () {
                        checkIfNetworkIsAvailable();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF145A41), 
                          padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 10)),
                      child: Text(
                        tr(context, 'login_btn'), // 👈 دکمه ورود سه‌زبانه
                        style: const TextStyle(
                          fontFamily: 'IranYekan',
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const SignUpScreen()));
                },
                child: Text(
                  tr(context, 'no_account_signup'), // 👈 متن دکمه ثبت‌نام
                  style: const TextStyle(
                    fontFamily: 'IranYekan',
                    color: Colors.grey,
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