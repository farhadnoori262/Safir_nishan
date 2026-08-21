import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/pages/dashboard.dart';
import 'package:safir_drivers/pages/driverRegistration/driver_registration.dart';
import 'package:safir_drivers/widgets/blocked_screen.dart';
import '../../providers/auth_provider.dart';
import '../../utils/lang_helper.dart';

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

  // 🌐 منوی انتخاب زبان (متصل به AppLanguageProvider)
  void _showLanguageSelector(BuildContext context) {
    final langProvider = Provider.of<AppLanguageProvider>(context, listen: false);

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
              const Text(
                'انتخاب زبان / د ژبې انتخاب',
                style: TextStyle(fontFamily: 'IranYekan', fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 25),
              ListTile(
                leading: const Text('🇦🇫', style: TextStyle(fontSize: 22)),
                title: const Text('فارسی (دری)', style: TextStyle(fontFamily: 'IranYekan', fontSize: 16)),
                onTap: () {
                  langProvider.changeLanguage(const Locale('fa'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇦🇫', style: TextStyle(fontSize: 22)),
                title: const Text('پښتو', style: TextStyle(fontFamily: 'IranYekan', fontSize: 16)),
                onTap: () {
                  langProvider.changeLanguage(const Locale('ps'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
                title: const Text('English', style: TextStyle(fontSize: 16)),
                onTap: () {
                  langProvider.changeLanguage(const Locale('en'));
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
                          color: const Color(0xFF145A41).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF145A41)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language, color: Color(0xFF145A41), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'زبان / ژبه',
                              style: TextStyle(
                                fontFamily: 'IranYekan',
                                color: Color(0xFF145A41),
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
                  tr(context, 'register_title'),
                  style: const TextStyle(
                    fontFamily: 'IranYekan',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, 'register_subtitle'),
                  style: const TextStyle(
                    fontFamily: 'IranYekan',
                    fontSize: 14,
                    color: Colors.grey,
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
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '77 123 4567',
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF145A41), width: 2),
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.fromLTRB(12.0, 14.0, 8.0, 14.0),
                        child: InkWell(
                          onTap: () {
                            showCountryPicker(
                              context: context,
                              countryListTheme: const CountryListThemeData(
                                  borderRadius: BorderRadius.zero,
                                  bottomSheetHeight: 400),
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
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      suffixIcon: phoneController.text.length == 9
                          ? Container(
                              height: 20,
                              width: 20,
                              margin: const EdgeInsets.all(12.0),
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: Color(0xFF145A41)),
                              child: const Icon(
                                Icons.done,
                                size: 16,
                                color: Colors.white,
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
                      backgroundColor: const Color(0xFF145A41),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          )
                        : Text(
                            tr(context, 'btn_continue'),
                            style: const TextStyle(
                              fontFamily: 'IranYekan',
                              color: Colors.white,
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
                        tr(context, 'or_label'),
                        style: TextStyle(
                          fontFamily: 'IranYekan',
                          color: Colors.grey.shade500,
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
                                          commonMethods.displaySnackBar(tr(context, 'complete_documents_error'), context);
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
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authProvider.isGoogleSigInLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF145A41)),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google_logo.png',
                                height: 22,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, color: Colors.black87),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                tr(context, 'google_sign_in'),
                                style: const TextStyle(
                                  fontFamily: 'IranYekan',
                                  color: Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                Center(
                  child: Text(
                    tr(context, 'terms_and_conditions'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'IranYekan',
                      color: Colors.grey,
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
        tr(context, 'invalid_phone_error'),
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
