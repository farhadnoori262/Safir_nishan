import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:safir_drivers/global/global.dart'; 
import 'package:safir_drivers/methods/common_method.dart'; 
import 'package:safir_drivers/methods/image_picker_service.dart'; 
import 'package:safir_drivers/models/driver.dart'; 
import 'package:safir_drivers/models/vehicle_info.dart'; 
import 'package:safir_drivers/pages/profile/profile_page.dart'; 
import 'package:safir_drivers/providers/authentication_provider.dart'; 
import 'package:safir_drivers/utils/lang_helper.dart';
import 'package:http/http.dart' as http;

class RegistrationProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool _isFetchLoading = false;
  XFile? _profilePhoto;
  bool _isPhotoAdded = false;
  bool _isFormValidBasic = false;
  bool _isFormValidCninc = false;
  XFile? _cnicFrontImage;
  XFile? _cnicBackImage;
  XFile? _cnicWithSelfieImage;
  bool _isFormValidDrivingLicense = false;
  XFile? _drivingLicenseFrontImage;
  XFile? _drivingLicenseBackImage;
  String? _selectedVehicle;
  bool _isVehicleBasicFormValid = false;
  final RegExp licenseRegExp = RegExp(r'^[A-Z]{2}-\d{2}-\d{4}$');
  XFile? _vehicleImage;
  bool _isVehiclePhotoAdded = false;
  XFile? _vehicleRegistrationFrontImage;
  XFile? _vehicleRegistrationBackImage;
  bool _isDataFetched = false;
  bool get isDataFetched => _isDataFetched;
  final bool _currentDriverInfo = false;
  double _driverEarnings = 0.0;
  get driverEarnings => _driverEarnings;

  // 🇦🇫 متغیرهای پلاک اختصاصی افغانستان
  String _plateProvince = 'کابل';
  String _plateCategory = 'ش';
  String _plateType = 'شخصی';

  // گترها و سترهای پلاک
  String get plateProvince => _plateProvince;
  String get plateCategory => _plateCategory;
  String get plateType => _plateType;

  void setPlateProvince(String val) {
    _plateProvince = val;
    notifyListeners();
  }

  void setPlateCategory(String val) {
    _plateCategory = val;
    notifyListeners();
  }

  void setPlateType(String val) {
    _plateType = val;
    notifyListeners();
  }

  // کنترلرهای فیلدهای متنی
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cnicController = TextEditingController();
  final TextEditingController drivingLicenseController = TextEditingController();

  final TextEditingController brandController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController numberPlateController = TextEditingController();
  final TextEditingController productionYearController = TextEditingController();

  // گترها (Getters) و سترها (Setters) هماهنگ با صفحات برنامه
  XFile? get profilePhoto => _profilePhoto;
  bool get isPhotoAdded => _isPhotoAdded;
  bool get isFormValidBasic => _isFormValidBasic;
  bool get isLoading => _isLoading;
  bool get isFetchLoading => _isFetchLoading;
  bool get isFormValidCninc => _isFormValidCninc;
  bool get isFormValidDrivingLicnese => _isFormValidDrivingLicense;
  bool get isVehicleBasicFormValid => _isVehicleBasicFormValid;
  String? get selectedVehicle => _selectedVehicle;
  
  XFile? get vehicleRegistrationFrontImage => _vehicleRegistrationFrontImage;
  set vehicleRegistrationFrontImage(XFile? val) {
    _vehicleRegistrationFrontImage = val;
    notifyListeners();
  }

  XFile? get vehicleRegistrationBackImage => _vehicleRegistrationBackImage;
  set vehicleRegistrationBackImage(XFile? val) {
    _vehicleRegistrationBackImage = val;
    notifyListeners();
  }

  Timer? _debounce;

  CommonMethods commonMethods = CommonMethods();

  // گتر و ستر بخش سلفی و شناسنامه
  XFile? get cnicWithSelfieImage => _cnicWithSelfieImage;
  set cnicWithSelfieImage(XFile? val) {
    _cnicWithSelfieImage = val;
    notifyListeners();
  }

  XFile? get cnincFrontImage => _cnicFrontImage;
  set cnincFrontImage(XFile? val) {
    _cnicFrontImage = val;
    notifyListeners();
  }

  XFile? get cnincBackImage => _cnicBackImage;
  set cnincBackImage(XFile? val) {
    _cnicBackImage = val;
    notifyListeners();
  }

  // گتر و ستر گواهینامه رانندگی
  XFile? get drivingLicenseFrontImage => _drivingLicenseFrontImage;
  set drivingLicenseFrontImage(XFile? val) {
    _drivingLicenseFrontImage = val;
    notifyListeners();
  }

  XFile? get drivingLicenseBackImage => _drivingLicenseBackImage;
  set drivingLicenseBackImage(XFile? val) {
    _drivingLicenseBackImage = val;
    notifyListeners();
  }

  // گتر و ستر عکس خودرو
  XFile? get vehicleImage => _vehicleImage;
  set vehicleImage(XFile? val) {
    _vehicleImage = val;
    notifyListeners();
  }

  bool get isVehiclePhotoAdded => _isVehiclePhotoAdded;
  set isVehiclePhotoAdded(bool val) {
    _isVehiclePhotoAdded = val;
    notifyListeners();
  }

  void startLoading() {
    _isLoading = true;
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    notifyListeners();
  }

  void startFetchLoading() {
    _isFetchLoading = true;
    notifyListeners();
  }

  void stopFetchLoading() {
    _isFetchLoading = false;
    notifyListeners();
  }

  void initFields(AuthenticationProvider authProvider) {
    if (!authProvider.isGoogleSignedIn) {
      phoneController.text = authProvider.phoneNumber;
    }
    if (authProvider.isGoogleSignedIn) {
      emailController.text =
          authProvider.firebaseAuth.currentUser?.email ?? '';
      phoneController.text = '';
    }
    checkBasicFormValidity();
  }

  void checkBasicFormValidity() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _isFormValidBasic = firstNameController.text.isNotEmpty &&
          lastNameController.text.isNotEmpty &&
          emailController.text.isNotEmpty &&
          phoneController.text.isNotEmpty &&
          addressController.text.isNotEmpty &&
          dobController.text.isNotEmpty &&
          _profilePhoto != null;
      notifyListeners();
    });
  }

  void checkCNICFormValidity() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _isFormValidCninc = _cnicFrontImage != null &&
          _cnicBackImage != null &&
          cnicController.text.isNotEmpty &&
          cnicController.text.length == 13;
      notifyListeners();
    });
  }

  void checkDrivingLicenseFormValidity() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _isFormValidDrivingLicense = _drivingLicenseFrontImage != null &&
          _drivingLicenseBackImage != null &&
          drivingLicenseController.text.isNotEmpty &&
          licenseRegExp.hasMatch(drivingLicenseController.text);
      notifyListeners();
    });
  }

  void checkVehicleBasicFormValidity() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _isVehicleBasicFormValid = _selectedVehicle != null &&
          brandController.text.isNotEmpty &&
          colorController.text.isNotEmpty &&
          numberPlateController.text.isNotEmpty &&
          productionYearController.text.isNotEmpty;
      notifyListeners();
    });
  }

  void setSelectedVehicle(String vehicle) {
    _selectedVehicle = vehicle;
    checkVehicleBasicFormValidity();
    notifyListeners();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    dobController.dispose();
    cnicController.dispose();
    emailController.dispose();
    phoneController.dispose();
    drivingLicenseController.dispose();
    brandController.dispose();
    colorController.dispose();
    numberPlateController.dispose();
    productionYearController.dispose();
    super.dispose();
  }

  Future<void> pickProfileImageFromGallary() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      _profilePhoto = image;
      _isPhotoAdded = true;
      checkBasicFormValidity();
      notifyListeners();
    }
  }

  Future<void> pickVehicleImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      _vehicleImage = image;
      _isVehiclePhotoAdded = true;
      notifyListeners();
    }
  }

  Future<void> pickAndCropCnincImage(bool isFrontImage) async {
    final ImagePickerService imagePickerService = ImagePickerService();

    final pickedFile = await imagePickerService.pickCropImage(
      cropAspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      imageSource: ImageSource.camera,
    );

    if (pickedFile != null) {
      if (isFrontImage) {
        _cnicFrontImage = pickedFile;
      } else {
        _cnicBackImage = pickedFile;
      }
      checkCNICFormValidity();
    }
  }

  Future<void> pickAndCropVehicleRegistrationImages(bool isFrontImage) async {
    final ImagePickerService imagePickerService = ImagePickerService();

    final pickedFile = await imagePickerService.pickCropImage(
      cropAspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 12),
      imageSource: ImageSource.camera,
    );

    if (pickedFile != null) {
      if (isFrontImage) {
        _vehicleRegistrationFrontImage = pickedFile;
      } else {
        _vehicleRegistrationBackImage = pickedFile;
      }
    }
    notifyListeners();
  }

  Future<void> pickAndCropDrivingLicenseImage(bool isFrontImage) async {
    final ImagePickerService imagePickerService = ImagePickerService();

    final pickedFile = await imagePickerService.pickCropImage(
      cropAspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      imageSource: ImageSource.camera,
    );

    if (pickedFile != null) {
      if (isFrontImage) {
        _drivingLicenseFrontImage = pickedFile;
      } else {
        _drivingLicenseBackImage = pickedFile;
      }
      checkDrivingLicenseFormValidity();
    }
  }

  Future<void> pickCnincImageWithSelfie() async {
    final ImagePickerService imagePickerService = ImagePickerService();

    final pickedFile = await imagePickerService.pickCropImage(
      cropAspectRatio: const CropAspectRatio(ratioX: 20, ratioY: 20),
      imageSource: ImageSource.camera,
    );

    if (pickedFile != null) {
      _cnicWithSelfieImage = pickedFile;
    }
    notifyListeners();
  }

  // آپلود عکس به استوریج فایربیس
  Future<String> uploadImageToFirebaseStorage(XFile? photo, String? path, BuildContext context) async {
    if (photo == null) {
      throw Exception(tr(context, 'err_no_image_selected'));
    }
    if (_auth.currentUser == null) throw Exception("User not authenticated");
    String imageIDName = DateTime.now().millisecondsSinceEpoch.toString();
    final file = File(photo.path);
    final reference = _storage
        .ref()
        .child(_auth.currentUser!.uid)
        .child(path!)
        .child(imageIDName);
    final uploadTask = reference.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> saveUserData(BuildContext context) async {
    if (!isFormValidBasic ||
        !isFormValidCninc ||
        !isFormValidDrivingLicnese ||
        !isVehicleBasicFormValid) {
      commonMethods.displaySnackBar(tr(context, 'err_fill_all_fields'), context);
      return;
    }
    try {
      startLoading();
      final profilePictureUrl =
          await uploadImageToFirebaseStorage(_profilePhoto, "ProfilePicture", context);

      final frontCnincImageUrl =
          await uploadImageToFirebaseStorage(_cnicFrontImage, "Cninc", context);
      final backCnincImageUrl =
          await uploadImageToFirebaseStorage(_cnicBackImage, "Cninc", context);
      final faceWithCnincImageUrl = await uploadImageToFirebaseStorage(
          _cnicWithSelfieImage, "SelfieWithCninc", context);
      final drivingLicenseFrontImageUrl = await uploadImageToFirebaseStorage(
          _drivingLicenseFrontImage, "DrivingLicenseImages", context);
      final drivingLicenseBackImageUrl = await uploadImageToFirebaseStorage(
          _drivingLicenseBackImage, "DrivingLicenseImages", context);
      final vehicleImageUrl =
          await uploadImageToFirebaseStorage(_vehicleImage, "VehicleImage", context);
      final vehicleRegistrationFrontImageUrl =
          await uploadImageToFirebaseStorage(
              _vehicleRegistrationFrontImage, "VehicleRegistrationImages", context);
      final vehicleRegistrationBackImageUrl =
          await uploadImageToFirebaseStorage(
              _vehicleRegistrationBackImage, "VehicleRegistrationImages", context);

      final driver = Driver(
        id: _auth.currentUser!.uid,
        profilePicture: profilePictureUrl,
        firstName: firstNameController.text,
        secondName: lastNameController.text,
        phoneNumber: phoneController.text,
        address: addressController.text,
        dob: dobController.text,
        email: emailController.text,
        cnicNumber: cnicController.text, 
        cnicFrontImage: frontCnincImageUrl,
        cnicBackImage: backCnincImageUrl,
        driverFaceWithCnic: faceWithCnincImageUrl,
        drivingLicenseNumber: drivingLicenseController.text,
        drivingLicenseFrontImage: drivingLicenseFrontImageUrl,
        drivingLicenseBackImage: drivingLicenseBackImageUrl,
        blockStatus: "no",
        deviceToken: '',
        earnings: '0',
        driverRatings: '0',
        vehicleInfo: VehicleInfo(
          type: selectedVehicle.toString(),
          brand: brandController.text,
          color: colorController.text,
          vehiclePicture: vehicleImageUrl,
          productionYear: productionYearController.text,
          registrationPlateNumber: numberPlateController.text,
          plateProvince: _plateProvince,
          plateCategory: _plateCategory,
          plateType: _plateType,
          registrationCertificateBackImage: vehicleRegistrationFrontImageUrl,
          registrationCertificateFrontImage: vehicleRegistrationBackImageUrl,
        ), 
      );

      final userRef =
          _database.ref().child("drivers").child(_auth.currentUser!.uid);
      await userRef.set(driver.toMap());
      stopLoading();
    } catch (e) {
      stopLoading();
      print("Error saving driver data: $e");
    }
  }

  Future<void> fetchUserData() async {
    if (_isDataFetched || _auth.currentUser == null) {
      return; 
    }
    try {
      startFetchLoading();
      final userRef =
          _database.ref().child("drivers").child(_auth.currentUser!.uid);

      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        firstNameController.text = data['firstName'] ?? '';
        lastNameController.text = data['secondName'] ?? '';
        phoneController.text = data['phoneNumber'] ?? '';
        addressController.text = data['address'] ?? '';
        dobController.text = data['dob'] ?? '';
        emailController.text = data['email'] ?? '';
        cnicController.text = data['cnicNumber'] ?? '';
        drivingLicenseController.text = data['drivingLicenseNumber'] ?? '';
        _selectedVehicle = data['vehicleInfo']?['type'] ?? '';
        brandController.text = data['vehicleInfo']?['brand'] ?? '';
        colorController.text = data['vehicleInfo']?['color'] ?? '';
        numberPlateController.text =
            data['vehicleInfo']?['registrationPlateNumber'] ?? '';
        _plateProvince = data['vehicleInfo']?['plateProvince'] ?? 'کابل';
        _plateCategory = data['vehicleInfo']?['plateCategory'] ?? 'ش';
        _plateType = data['vehicleInfo']?['plateType'] ?? 'شخصی';
        productionYearController.text =
            data['vehicleInfo']?['productionYear'] ?? '';

        _profilePhoto = await _fetchImageFromUrl(data['profilePicture'] ?? '');
        _cnicFrontImage = await _fetchImageFromUrl(data['cnicFrontImage'] ?? '');
        _cnicBackImage = await _fetchImageFromUrl(data['cnicBackImage'] ?? '');
        _cnicWithSelfieImage =
            await _fetchImageFromUrl(data['driverFaceWithCnic'] ?? '');
        _drivingLicenseFrontImage =
            await _fetchImageFromUrl(data['drivingLicenseFrontImage'] ?? '');
        _drivingLicenseBackImage =
            await _fetchImageFromUrl(data['drivingLicenseBackImage'] ?? '');
        _vehicleImage =
            await _fetchImageFromUrl(data['vehicleInfo']?['vehiclePicture'] ?? '');
        _vehicleRegistrationFrontImage = await _fetchImageFromUrl(
            data['vehicleInfo']?['registrationCertificateFrontImage'] ?? '');
        _vehicleRegistrationBackImage = await _fetchImageFromUrl(
            data['vehicleInfo']?['registrationCertificateBackImage'] ?? '');
        
        _isDataFetched = true;
        stopFetchLoading();
        notifyListeners();
      } else {
        stopFetchLoading();
      }
    } catch (e) {
      print("Error loading driver data: $e");
      stopFetchLoading();
    }
  }

  Future<XFile?> _fetchImageFromUrl(String url) async {
    if (url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        return XFile(file.path);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchDriverEarnings() async {
    try {
      if (_auth.currentUser == null) return;
      final userId = _auth.currentUser!.uid;
      DatabaseReference driverRef =
          _database.ref().child("drivers").child(userId);

      final snapshot = await driverRef.child("earnings").get();
      if (snapshot.exists) {
        double earnings = double.tryParse(snapshot.value.toString()) ?? 0.0;
        _driverEarnings = double.parse(earnings.toStringAsFixed(2));
        notifyListeners(); 
      } else {
        _driverEarnings = 0.0;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching driver's earnings: $e");
    }
  }

  Future<void> retrieveCurrentDriverInfo() async {
    try {
      if (_auth.currentUser == null) return;
      final driverId = _auth.currentUser!.uid;
      DatabaseReference driverRef =
          _database.ref().child("drivers").child(driverId);
      final snapshot = await driverRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        driverName = data['firstName'] ?? '';
        driverSecondName = data['secondName'] ?? '';
        driverPhone = data['phoneNumber'] ?? '';
        driverEmail = data['email'] ?? '';
        address = data['address'] ?? '';
        rating = data['driverRatings'] ?? '';
        driverPhoto = data['profilePicture'] ?? '';
        carModel = data['vehicleInfo']?['brand'] ?? '';
        carColor = data['vehicleInfo']?['color'] ?? '';
        carNumber = data['vehicleInfo']?['registrationPlateNumber'] ?? '';

        notifyListeners();
      }
    } catch (e) {
      print("Error retrieving current driver profile: $e");
    }
  }

  Future<void> updateBasicDriverInfo(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();
      final newProfilePicture =
          await uploadImageToFirebaseStorage(_profilePhoto, "ProfilePicture", context);
      final driverData = {
        'firstName': firstNameController.text,
        'secondName': lastNameController.text,
        'email': emailController.text,
        'address': addressController.text,
        'phoneNumber': phoneController.text,
        'dob': dobController.text,
        'profilePicture': newProfilePicture,
      };
      final userRef =
          _database.ref().child("drivers").child(_auth.currentUser!.uid);
      await userRef.update(driverData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print("An error occurred: $e");
      _isLoading = false;
    }
  }

  Future<void> updateCnincInfo(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();
      final frontCnincImageUrl =
          await uploadImageToFirebaseStorage(_cnicFrontImage, "Cninc", context);
      final backCnincImageUrl =
          await uploadImageToFirebaseStorage(_cnicBackImage, "Cninc", context);
      final driverData = {
        'cnicFrontImage': frontCnincImageUrl,
        'cnicBackImage': backCnincImageUrl,
        'cnicNumber': cnicController.text,
      };
      final userRef =
          _database.ref().child("drivers").child(_auth.currentUser!.uid);
      await userRef.update(driverData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
    }
  }

  Future<void> updateSelfieWithCnincInfo(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();
      final faceWithCnincImageUrl = await uploadImageToFirebaseStorage(
          _cnicWithSelfieImage, "SelfieWithCninc", context);
      final driverData = {
        'driverFaceWithCnic': faceWithCnincImageUrl,
      };
      final userRef =
          _database.ref().child("drivers").child(_auth.currentUser!.uid);
      await userRef.update(driverData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
    }
  }

  Future<void> updatedriverLicenseInfo(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();
      final drivingLicenseFrontImageUrl = await uploadImageToFirebaseStorage(
          _drivingLicenseFrontImage, "DrivingLicenseImages", context);
      final drivingLicenseBackImageUrl = await uploadImageToFirebaseStorage(
          _drivingLicenseBackImage, "DrivingLicenseImages", context);
      final driverData = {
        'driverLicenseFrontImage': drivingLicenseFrontImageUrl,
        'driverLicenseBackImage': drivingLicenseBackImageUrl,
        'driverLicenseNumber': drivingLicenseController.text,
      };
      final userRef =
          _database.ref().child("drivers").child(_auth.currentUser!.uid);
      await userRef.update(driverData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
    }
  }

  Future<void> updateVehicleBasicInfo(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();
      final vehicleData = {
        'type': selectedVehicle,
        'brand': brandController.text,
        'color': colorController.text,
        'productionYear': productionYearController.text,
        'registrationPlateNumber': numberPlateController.text,
        'plateProvince': _plateProvince,
        'plateCategory': _plateCategory,
        'plateType': _plateType,
      };
      final userRef = _database
          .ref()
          .child("drivers")
          .child(_auth.currentUser!.uid)
          .child("vehicleInfo");
      await userRef.update(vehicleData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
    }
  }

  Future<void> updateVehicleImage(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();
      final vehicleImageUrl =
          await uploadImageToFirebaseStorage(_vehicleImage, "VehicleImage", context);
      final vehicleData = {
        'vehiclePicture': vehicleImageUrl,
      };
      final userRef = _database
          .ref()
          .child("drivers")
          .child(_auth.currentUser!.uid)
          .child("vehicleInfo");
      await userRef.update(vehicleData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
    }
  }

  Future<void> updateVehicleRegistraionImages(BuildContext context) async {
    try {
      _isLoading = true;
      notifyListeners();
      final vehicleRegistrationFrontImageUrl =
          await uploadImageToFirebaseStorage(
              _vehicleRegistrationFrontImage, "VehicleRegistrationImages", context);
      final vehicleRegistrationBackImageUrl =
          await uploadImageToFirebaseStorage(
              _vehicleRegistrationBackImage, "VehicleRegistrationImages", context);
      final vehicleData = {
        'registrationCertificateFrontImage': vehicleRegistrationFrontImageUrl,
        'registrationCertificateBackImage': vehicleRegistrationBackImageUrl,
      };
      final userRef = _database
          .ref()
          .child("drivers")
          .child(_auth.currentUser!.uid)
          .child("vehicleInfo");
      await userRef.update(vehicleData);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
    }
  }
}
