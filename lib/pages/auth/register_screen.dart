import 'package:country_picker/country_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../methods/common_method.dart';
import '../../pages/dashboard.dart';
import '../../pages/driverRegistration/driver_registration.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/blocked_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController phoneController = TextEditingController();

  // تنظیم کشور پیش‌فرض روی افغانستان برای اپلیکیشن سفیر
  Country selectedCountry = Country(
    phoneCode: '93',
    countryCode: 'AF',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Afghanistan',
    example: 'Afghanistan',
    displayName: 'Afghanistan',
    displayNameNoCountryCode: 'AF',
    e164Key: '',
  );

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  CommonMethods commonMethods = CommonMethods();

  // 🌐 منوی انتخاب زبان
  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'select_language'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Divider(height: 25),
              ListTile(
                leading: const Text('🇦🇫', style: TextStyle(fontSize: 22)),
                title: const Text('فارسی (دری)', style: TextStyle(fontSize: 16)),
                onTap: () {
                  context.setLocale(const Locale('fa'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇦🇫', style: TextStyle(fontSize: 22)),
                title: const Text('پښتو', style: TextStyle(fontSize: 16)),
                onTap: () {
                  context.setLocale(const Locale('ps'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
                title: const Text('English', style: TextStyle(fontSize: 16)),
                onTap: () {
                  context.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌐 دکمه تغییر زبان بالای صفحه
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    InkWell(
                      onTap: () => _showLanguageSelector(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBrand.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primaryBrand),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language, color: AppColors.primaryBrand, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'language_button'.tr(),
                              style: const TextStyle(
                                color: AppColors.primaryBrand,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text(
                  'register_title'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'register_subtitle'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    controller: phoneController,
                    maxLength: 9,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: AppColors.textPrimary,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '77 123 4567',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryBrand, width: 2),
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.fromLTRB(12.0, 14.0, 8.0, 14.0),
                        child: InkWell(
                          onTap: () {
                            showCountryPicker(
                              context: context,
                              countryListTheme: const CountryListThemeData(
                                borderRadius: BorderRadius.zero,
                                bottomSheetHeight: 400,
                              ),
                              onSelect: (value) {
                                setState(() {
                                  selectedCountry = value;
                                });
                              },
                            );
                          },
                          child: Text(
                            ' +${selectedCountry.phoneCode}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      suffixIcon: phoneController.text.length == 9
                          ? Container(
                              height: 20,
                              width: 20,
                              margin: const EdgeInsets.all(12.0),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryBrand,
                              ),
                              child: const Icon(
                                Icons.done,
                                size: 16,
                                color: AppColors.buttonText,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: sendPhoneNumber,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryButton,
                      foregroundColor: AppColors.buttonText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.buttonText,
                          )
                        : Text(
                            'btn_continue'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'or_label'.tr(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            if (!authProvider.isLoading) {
                              await authProvider.signInWithGoogle(
                                context,
                                () async {
                                  bool userExists = await authProvider.checkUserExistById();
                                  bool userExistsInDatabase = await authProvider.checkUserExistByEmail(
                                    authProvider.firebaseAuth.currentUser!.email!.toString(),
                                  );

                                  if (userExists) {
                                    if (userExistsInDatabase) {
                                      bool isBlocked = await authProvider.checkIfDriverIsBlocked();

                                      if (isBlocked) {
                                        if (!mounted) return;
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const BlockedScreen()),
                                        );
                                      } else {
                                        await authProvider.getUserDataFromFirebaseDatabase();
                                        bool isDriverComplete = await authProvider.checkDriverFieldsFilled();

                                        if (isDriverComplete) {
                                          navigate(isSingedIn: true);
                                        } else {
                                          navigate(isSingedIn: false);
                                          if (!mounted) return;
                                          commonMethods.displaySnackBar('complete_documents_error'.tr(), context);
                                        }
                                      }
                                    } else {
                                      navigate(isSingedIn: false);
                                    }
                                  } else {
                                    navigate(isSingedIn: false);
                                  }
                                },
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authProvider.isGoogleSigInLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBrand),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google_logo.png',
                                height: 22,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, color: AppColors.textPrimary),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'google_sign_in'.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                Center(
                  child: Text(
                    'terms_and_conditions'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
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

  void sendPhoneNumber() {
    final authRepo = Provider.of<AuthenticationProvider>(context, listen: false);
    String phoneNumber = phoneController.text.trim();

    if (phoneNumber.isEmpty || phoneNumber.length != 9 || !RegExp(r'^[7][0-9]{8}$').hasMatch(phoneNumber)) {
      commonMethods.displaySnackBar(
        'invalid_phone_error'.tr(),
        context,
      );
      return;
    }

    String fullPhoneNumber = '+${selectedCountry.phoneCode}$phoneNumber';

    authRepo.signInWithPhone(
      context: context,
      phoneNumber: fullPhoneNumber,
    );
  }

  void navigate({required bool isSingedIn}) {
    if (!mounted) return;
    if (isSingedIn) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Dashboard()),
          (route) => false);
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const DriverRegistration()));
    }
  }
}
