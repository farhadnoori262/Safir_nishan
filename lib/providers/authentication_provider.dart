import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:safir_drivers/models/driver.dart'; 
import 'package:safir_drivers/pages/auth/register_screen.dart'; 
import 'package:safir_drivers/utils/lang_helper.dart';
import '../methods/common_method.dart';
import '../models/vehicle_info.dart';
import '../pages/auth/otp_screen.dart';

// 🔢 متد کمکی تبدیل اعداد انگلیسی به فارسی/پشتو بر اساس زبان فعال
extension PersianNumberExtension on String {
  String toPersianDigits(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      return this;
    }
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const farsi   = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    
    String output = this;
    for (int i = 0; i < english.length; i++) {
      output = output.replaceAll(english[i], farsi[i]);
    }
    return output;
  }
}

class AuthenticationProvider extends ChangeNotifier {
  CommonMethods commonMethods = CommonMethods();
  bool _isLoading = false;
  bool _isSuccessful = false;
  bool _isGoogleSignedIn = false;
  bool _isGoogleSignInLoading = false;
  String? _uid;
  String? _phoneNumber;

  Driver? _driverModel;

  Driver get driverModel => _driverModel!;

  String? get uid => _uid;
  String get phoneNumber => _phoneNumber!;
  bool get isSuccessful => _isSuccessful;
  bool get isLoading => _isLoading;
  bool get isGoogleSignedIn => _isGoogleSignedIn;
  bool get isGoogleSigInLoading => _isGoogleSignInLoading;

  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage firebaseStorage = FirebaseStorage.instance;
  final FirebaseDatabase firebaseDatabase = FirebaseDatabase.instance; 
  final GoogleSignIn googleSignIn = GoogleSignIn(); 

  void startLoading() {
    _isLoading = true;
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    notifyListeners();
  }

  void startGoogleLoading() {
    _isGoogleSignInLoading = true;
    notifyListeners();
  }

  void stopGoogleLoading() {
    _isGoogleSignInLoading = false;
    notifyListeners();
  }

  // ورود/ثبت‌نام با شماره تلفن
  void signInWithPhone({
    required BuildContext context,
    required String phoneNumber,
  }) async {
    startLoading(); 

    try {
      await firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await firebaseAuth.signInWithCredential(credential);
          stopLoading(); 
        },
        verificationFailed: (FirebaseAuthException e) {
          stopLoading(); 
          if (context.mounted) {
            commonMethods.displaySnackBar("${tr(context, 'err_phone_verify')}: ${e.message}", context);
          }
          throw Exception(e.toString());
        },
        codeSent: (String verificationId, int? resendToken) {
          stopLoading(); 
          _phoneNumber = phoneNumber;
          notifyListeners();
          
          Future.delayed(const Duration(seconds: 1)).whenComplete(() {
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OTPScreen(
                    verificationId: verificationId,
                  ),
                ),
              );
            }
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          stopLoading(); 
        },
      );
    } on FirebaseException catch (e) {
      stopLoading(); 
      if (context.mounted) {
        commonMethods.displaySnackBar(e.message ?? tr(context, 'err_generic'), context);
      }
    }
  }

  // تایید کد امنیتی SMS
  void verifyOTP({
    required BuildContext context,
    required String verificationId,
    required String smsCode,
    required Function onSuccess,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      PhoneAuthCredential phoneAuthCredential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      User? user =
          (await firebaseAuth.signInWithCredential(phoneAuthCredential)).user;

      if (user != null) {
        _uid = user.uid;
        notifyListeners();
        onSuccess();
      }

      _isLoading = false;
      _isSuccessful = true;
      notifyListeners();
    } on FirebaseException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (context.mounted) {
        commonMethods.displaySnackBar(tr(context, 'err_invalid_otp'), context);
      }
    }
  }

  // ذخیره اطلاعات کامل راننده در فایربیس دیتابیس
  void saveUserDataToFirebase({
    required BuildContext context,
    required Driver driverModel,
    required VoidCallback onSuccess,
  }) async {
    startLoading();
    notifyListeners();

    try {
      DatabaseReference usersRef =
          firebaseDatabase.ref().child("drivers").child(driverModel.id);
      await usersRef.set(driverModel.toMap()).then((value) {
        stopLoading();
        notifyListeners();
        onSuccess();
      });
    } on FirebaseException catch (e) {
      stopLoading();
      notifyListeners();
      if (context.mounted) {
        commonMethods.displaySnackBar(e.message ?? tr(context, 'err_save_failed'), context);
      }
    }
  }

  Future<bool> checkUserExistByEmail(String email) async {
    DatabaseReference usersRef = firebaseDatabase.ref().child("drivers");
    DatabaseEvent snapshot =
        await usersRef.orderByChild("email").equalTo(email).once();

    return snapshot.snapshot.exists;
  }

  Future<bool> checkUserExistById() async {
    if (FirebaseAuth.instance.currentUser == null) return false;
    DatabaseReference usersRef = firebaseDatabase.ref().child("drivers");
    DatabaseEvent snapshot = await usersRef
        .orderByChild("id") 
        .equalTo(FirebaseAuth.instance.currentUser!.uid)
        .once();

    return snapshot.snapshot.exists;
  }

  // دریافت اطلاعات کامل راننده همراه با جزییات پلاک افغانستان
  Future<void> getUserDataFromFirebaseDatabase() async {
    try {
      if (firebaseAuth.currentUser == null) return;
      DatabaseReference driverRef = firebaseDatabase
          .ref()
          .child("drivers")
          .child(firebaseAuth.currentUser!.uid);

      DataSnapshot snapshot = await driverRef.get();

      if (snapshot.exists && snapshot.value != null) {
        Map driverData = snapshot.value as Map;

        _driverModel = Driver(
          id: driverData["id"] ?? '',
          firstName: driverData["firstName"] ?? '',
          secondName: driverData["secondName"] ?? '',
          phoneNumber: driverData["phoneNumber"] ?? '',
          address: driverData["address"] ?? '',
          profilePicture: driverData["profilePicture"] ?? '',
          dob: driverData["dob"] ?? '',
          email: driverData["email"] ?? '',
          cnicNumber: driverData["cnicNumber"] ?? '',
          cnicFrontImage: driverData["cnicFrontImage"] ?? '',
          cnicBackImage: driverData["cnicBackImage"] ?? '',
          driverFaceWithCnic: driverData["driverFaceWithCnic"] ?? '',
          drivingLicenseNumber: driverData["drivingLicenseNumber"] ?? '',
          drivingLicenseFrontImage:
              driverData["drivingLicenseFrontImage"] ?? '',
          drivingLicenseBackImage: driverData["drivingLicenseBackImage"] ?? '',
          blockStatus: driverData["blockStatus"] ?? '',
          deviceToken: driverData["deviceToken"] ?? '',
          driverRatings: driverData["driverRattings"] ?? '',
          earnings: driverData["earnings"] ?? '',
          vehicleInfo: VehicleInfo(
            brand: driverData["vehicleInfo"]?["brand"] ?? '',
            color: driverData["vehicleInfo"]?["color"] ?? '',
            productionYear: driverData["vehicleInfo"]?["productionYear"] ?? '',
            vehiclePicture: driverData["vehicleInfo"]?["vehiclePicture"] ?? '',
            type: driverData["vehicleInfo"]?["type"] ?? '',
            registrationPlateNumber:
                driverData["vehicleInfo"]?["registrationPlateNumber"] ?? '',
            // 🇦🇫 اضافه شدن فیلدهای پلاک افغانستان
            plateProvince: driverData["vehicleInfo"]?["plateProvince"] ?? 'کابل',
            plateCategory: driverData["vehicleInfo"]?["plateCategory"] ?? 'ش',
            plateType: driverData["vehicleInfo"]?["plateType"] ?? 'شخصی',
            registrationCertificateFrontImage: driverData["vehicleInfo"]
                    ?["registrationCertificateFrontImage"] ??
                '',
            registrationCertificateBackImage: driverData["vehicleInfo"]
                    ?["registrationCertificateBackImage"] ??
                '',
          ),
        );

        _uid = _driverModel!.id;
        notifyListeners(); 
      } else {
        print("Driver data not found.");
      }
    } catch (e) {
      print("Error fetching driver data: $e");
    }
  }

  // بررسی کامل پر بودن تمام فیلدها جهت احراز هویت
  Future<bool> checkDriverFieldsFilled() async {
    try {
      if (firebaseAuth.currentUser == null) return false;
      DatabaseReference driverRef = firebaseDatabase
          .ref()
          .child("drivers")
          .child(firebaseAuth.currentUser!.uid);

      DataSnapshot snapshot = await driverRef.get();

      if (snapshot.exists && snapshot.value != null) {
        Map driverData = snapshot.value as Map;

        String profilePicture = driverData["profilePicture"] ?? '';
        String firstName = driverData["firstName"] ?? '';
        String secondName = driverData["secondName"] ?? '';
        String phoneNumber = driverData["phoneNumber"] ?? '';
        String dob = driverData["dob"] ?? '';
        String email = driverData["email"] ?? '';
        String cnicNumber = driverData["cnicNumber"] ?? '';
        String cnicFrontImage = driverData["cnicFrontImage"] ?? '';
        String cnicBackImage = driverData["cnicBackImage"] ?? '';
        String driverFaceWithCnic = driverData["driverFaceWithCnic"] ?? '';
        String drivingLicenseNumber = driverData["drivingLicenseNumber"] ?? '';
        String drivingLicenseFrontImage =
            driverData["drivingLicenseFrontImage"] ?? '';
        String drivingLicenseBackImage =
            driverData["drivingLicenseBackImage"] ?? '';

        Map vehicleInfo = driverData["vehicleInfo"] ?? {};
        String carBrand = vehicleInfo["brand"] ?? '';
        String carColor = vehicleInfo["color"] ?? '';
        String productionYear = vehicleInfo["productionYear"] ?? '';
        String vehiclePicture = vehicleInfo["vehiclePicture"] ?? '';
        String vehicleType = vehicleInfo["type"] ?? '';
        String registrationPlateNumber =
            vehicleInfo["registrationPlateNumber"] ?? '';
        String registrationCertificateFrontImage =
            vehicleInfo["registrationCertificateFrontImage"] ?? '';
        String registrationCertificateBackImage =
            vehicleInfo["registrationCertificateBackImage"] ?? '';

        if (profilePicture.isEmpty ||
            firstName.isEmpty ||
            secondName.isEmpty ||
            phoneNumber.isEmpty ||
            dob.isEmpty ||
            email.isEmpty ||
            cnicNumber.isEmpty ||
            cnicFrontImage.isEmpty ||
            cnicBackImage.isEmpty ||
            driverFaceWithCnic.isEmpty ||
            drivingLicenseNumber.isEmpty ||
            drivingLicenseFrontImage.isEmpty ||
            drivingLicenseBackImage.isEmpty ||
            carBrand.isEmpty ||
            carColor.isEmpty ||
            productionYear.isEmpty ||
            vehiclePicture.isEmpty ||
            vehicleType.isEmpty ||
            registrationPlateNumber.isEmpty ||
            registrationCertificateFrontImage.isEmpty ||
            registrationCertificateBackImage.isEmpty) {
          return false; 
        } else {
          return true; 
        }
      } else {
        return false;
      }
    } catch (e) {
      print("Error checking driver fields: $e");
      return false;
    }
  }

  Future<void> signInWithGoogle(
      BuildContext context, VoidCallback onSuccess) async {
    startGoogleLoading();
    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        stopGoogleLoading();
        return; 
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        _uid = user.uid;
        _isGoogleSignedIn = true;
        notifyListeners();
      }
      onSuccess();

      stopGoogleLoading();
    } on FirebaseAuthException catch (e) {
      stopGoogleLoading();
      if (context.mounted) {
        commonMethods.displaySnackBar(
            e.message ?? tr(context, 'err_google_sign_in'), context);
      }
    }
  }

  Future<bool> checkIfDriverIsBlocked() async {
    try {
      if (firebaseAuth.currentUser == null) return false;
      DatabaseReference driverRef = firebaseDatabase
          .ref()
          .child("drivers")
          .child(firebaseAuth.currentUser!.uid);

      DataSnapshot snapshot = await driverRef.get();

      if (snapshot.exists && snapshot.value != null) {
        Map driverData = snapshot.value as Map;
        String blockStatus = driverData["blockStatus"] ?? 'no';

        if (blockStatus == 'yes') {
          await firebaseAuth.signOut();
          await googleSignIn.signOut();

          _uid = null;
          _isGoogleSignedIn = false;
          notifyListeners();
          return true; 
        } else {
          return false; 
        }
      } else {
        return false; 
      }
    } catch (e) {
      print("Error checking block status: $e");
      return false; 
    }
  }

  Future<void> signOut(BuildContext context) async {
    startLoading();
    try {
      await firebaseAuth.signOut();
      await googleSignIn.signOut();

      _uid = null;
      _isGoogleSignedIn = false;
      notifyListeners();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  const RegisterScreen()), 
          (route) => false,
        );
      }

      stopLoading();
    } on FirebaseAuthException catch (e) {
      stopLoading();
      if (context.mounted) {
        commonMethods.displaySnackBar(e.message ?? tr(context, 'err_sign_out'), context);
      }
    }
  }
}
