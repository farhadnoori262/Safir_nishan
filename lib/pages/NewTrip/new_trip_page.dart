import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:safir_drivers/constants/trip_status.dart';

import '../../global/global.dart';
import '../../methods/common_method.dart';
import '../../models/trip_details.dart';
import '../../utils/app_colors.dart';
import '../../widgets/loading_dialog.dart';
import '../../widgets/payment_dialog.dart';

class NewTripPage extends StatefulWidget {
  final TripDetails? newTripDetailsInfo;

  const NewTripPage({
    super.key,
    this.newTripDetailsInfo,
  });

  @override
  State<NewTripPage> createState() => _NewTripPageState();
}

class _NewTripPageState extends State<NewTripPage> {
  String statusOfTrip = TripStatus.accepted;
  String buttonTitleKey = 'btn_arrived';
  Color buttonColor = AppColors.primaryButton;

  final CommonMethods commonMethods = CommonMethods();

  bool _isProcessing = false;
  bool _tripCancelled = false;

  String get _tripId => widget.newTripDetailsInfo?.tripID ?? '';

  DocumentReference<Map<String, dynamic>> get _tripRef =>
      FirebaseFirestore.instance.collection('rides').doc(_tripId);

  Future<void> _openExternalNavigationApp(
    double lat,
    double lng,
  ) async {
    final Uri neshanUri = Uri.parse(
      'neshan://navi?lat=$lat&lng=$lng',
    );

    final Uri googleUri = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d',
    );

    final Uri webUri = Uri.parse(
      'https://www.google.com/maps/dir/'
      '?api=1&destination=$lat,$lng&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(neshanUri)) {
        await launchUrl(
          neshanUri,
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      if (await canLaunchUrl(googleUri)) {
        await launchUrl(
          googleUri,
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Navigation app error: $e');

      await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<String?> _getCurrentTripStatus() async {
    if (_tripId.isEmpty) {
      return null;
    }

    final snapshot = await _tripRef.get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data() ?? {};

    return data['status']?.toString();
  }

  bool _isCancelledStatus(String status) {
    return status == TripStatus.cancelledByDriver ||
        status == TripStatus.cancelledByPassenger;
  }

  Future<void> _showStatusError(String message) async {
    if (!mounted) return;

    commonMethods.displaySnackBar(message, context);
  }

  Future<void> _stopLocationUpdates() async {
    try {
      await positionStreamNewTripPage?.cancel();
      positionStreamNewTripPage = null;
    } catch (e) {
      debugPrint('Stop location stream error: $e');
    }
  }

  Future<void> _goBackToHome() async {
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  void getLiveLocationUpdatesOfDriver() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    positionStreamNewTripPage?.cancel();

    positionStreamNewTripPage = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position positionDriver) async {
        if (_tripCancelled || _tripId.isEmpty) {
          return;
        }

        driverCurrentPosition = positionDriver;

        try {
          final currentStatus = await _getCurrentTripStatus();

          if (currentStatus == null || _isCancelledStatus(currentStatus)) {
            _tripCancelled = true;
            await _stopLocationUpdates();
            return;
          }

          if (currentStatus != TripStatus.accepted &&
              currentStatus != TripStatus.arrived &&
              currentStatus != TripStatus.onTrip) {
            return;
          }

          await _tripRef.update({
            'driverLocation': {
              'latitude': positionDriver.latitude,
              'longitude': positionDriver.longitude,
            },
            'driver_lat': positionDriver.latitude,
            'driver_lng': positionDriver.longitude,
            'updated_at': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Driver location update error: $e');
        }
      },
      onError: (Object error) {
        debugPrint('Driver location stream error: $error');
      },
    );
  }

  Future<void> saveDriverDataToTripInfo() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || _tripId.isEmpty) {
      return;
    }

    try {
      final currentStatus = await _getCurrentTripStatus();

      if (currentStatus != TripStatus.accepted) {
        debugPrint(
          'Driver information was not saved. '
          'Trip status: $currentStatus',
        );
        return;
      }

      final DatabaseReference driverRef = FirebaseDatabase.instance
          .ref()
          .child('drivers')
          .child(currentUser.uid);

      final DataSnapshot snapshot = await driverRef.get();

      String realDriverName = '';
      String realDriverPhone = '';
      String realDriverPhoto = '';
      String fullCarPlate = '';
      String carModelName = '';
      String carColorName = '';

      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> data =
            snapshot.value as Map<dynamic, dynamic>;

        final String firstName = data['firstName']?.toString() ?? '';
        final String secondName = data['secondName']?.toString() ?? '';

        realDriverName = '$firstName $secondName'.trim();
        realDriverPhone = data['phoneNumber']?.toString() ?? '';
        realDriverPhoto = data['profilePicture']?.toString() ?? '';

        final dynamic vehicle = data['vehicleInfo'];

        if (vehicle is Map) {
          carModelName = vehicle['brand']?.toString() ?? '';
          carColorName = vehicle['color']?.toString() ?? '';

          final String rawPlate =
              vehicle['registrationPlateNumber']?.toString() ?? '';

          final String province =
              vehicle['plateProvince']?.toString() ?? '';

          final String category =
              vehicle['plateCategory']?.toString() ?? '';

          final String type =
              vehicle['plateType']?.toString() ?? '';

          if (province.isNotEmpty && rawPlate.isNotEmpty) {
            fullCarPlate = '$province - $category $rawPlate ($type)';
          } else {
            fullCarPlate = rawPlate;
          }
        }
      }

      final Map<String, dynamic> driverDataMap = {
        'driverId': currentUser.uid,
        'driver_id': currentUser.uid,
        'driverName': realDriverName.isNotEmpty
            ? realDriverName
            : '$driverName $driverSecondName',
        'driver_name': realDriverName.isNotEmpty
            ? realDriverName
            : '$driverName $driverSecondName',
        'driverPhone': realDriverPhone.isNotEmpty
            ? realDriverPhone
            : driverPhone,
        'driver_phone': realDriverPhone.isNotEmpty
            ? realDriverPhone
            : driverPhone,
        'driverPhoto': realDriverPhoto.isNotEmpty
            ? realDriverPhoto
            : driverPhoto,
        'driver_photo': realDriverPhoto.isNotEmpty
            ? realDriverPhoto
            : driverPhoto,
        'carDetails': '$carModelName - $fullCarPlate - $carColorName',
        'car_details': '$carModelName - $fullCarPlate - $carColorName',
        'carNumber': fullCarPlate,
        'car_number': fullCarPlate,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (driverCurrentPosition != null) {
        driverDataMap['driverLocation'] = {
          'latitude': driverCurrentPosition!.latitude,
          'longitude': driverCurrentPosition!.longitude,
        };

        driverDataMap['driver_lat'] = driverCurrentPosition!.latitude;
        driverDataMap['driver_lng'] = driverCurrentPosition!.longitude;
      }

      await _tripRef.update(driverDataMap);
    } catch (e) {
      debugPrint('Error saving driver data to trip: $e');
    }
  }

  Future<void> _cancelAcceptedTrip() async {
    if (_isProcessing || _tripId.isEmpty) {
      return;
    }

    final User? driver = FirebaseAuth.instance.currentUser;

    if (driver == null) {
      await _showStatusError('راننده وارد حساب کاربری نشده است.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final bool wasCancelled =
          await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final snapshot = await transaction.get(_tripRef);

          if (!snapshot.exists) {
            return false;
          }

          final data = snapshot.data() ?? {};
          final currentStatus = data['status']?.toString() ?? '';
          final assignedDriverId =
              data['driver_id']?.toString() ?? data['driverId']?.toString();

          if (assignedDriverId.isNotEmpty &&
              assignedDriverId != driver.uid) {
            return false;
          }

          if (currentStatus != TripStatus.accepted &&
              currentStatus != TripStatus.arrived &&
              currentStatus != TripStatus.onTrip) {
            return false;
          }

          transaction.update(_tripRef, {
            'status': TripStatus.cancelledByDriver,
            'cancelled_by': 'driver',
            'cancelled_by_driver_id': driver.uid,
            'cancelled_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

          return true;
        },
      );

      if (!wasCancelled) {
        await _showStatusError(
          'لغو انجام نشد؛ وضعیت سفر قبلاً تغییر کرده است.',
        );
        return;
      }

      _tripCancelled = true;

      await _stopLocationUpdates();

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driver.uid)
          .set({
        'newTripStatus': 'waiting',
        'isOnline': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      commonMethods.displaySnackBar('سفر لغو شد.', context);

      await Future.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, stackTrace) {
      debugPrint('Trip cancellation error: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _showStatusError(
        'لغو سفر انجام نشد. دوباره تلاش کنید.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _advanceTripStatus() async {
    if (_isProcessing || _tripCancelled) {
      return;
    }

    if (_tripId.isEmpty) {
      await _showStatusError('شناسه سفر موجود نیست.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final String? currentStatus = await _getCurrentTripStatus();

      if (currentStatus == null) {
        await _showStatusError('سفر پیدا نشد.');
        return;
      }

      if (_isCancelledStatus(currentStatus)) {
        _tripCancelled = true;
        await _stopLocationUpdates();

        await _showStatusError('این سفر لغو شده است.');
        return;
      }

      if (statusOfTrip == TripStatus.accepted) {
        if (currentStatus != TripStatus.accepted) {
          await _showStatusError(
            'وضعیت سفر تغییر کرده است: $currentStatus',
          );
          return;
        }

        await _tripRef.update({
          'status': TripStatus.arrived,
          'arrived_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          statusOfTrip = TripStatus.arrived;
          buttonTitleKey = 'btn_start_trip';
          buttonColor = AppColors.primaryBrand;
        });

        return;
      }

      if (statusOfTrip == TripStatus.arrived) {
        if (currentStatus != TripStatus.arrived) {
          await _showStatusError(
            'وضعیت سفر تغییر کرده است: $currentStatus',
          );
          return;
        }

        await _tripRef.update({
          'status': TripStatus.onTrip,
          'started_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          statusOfTrip = TripStatus.onTrip;
          buttonTitleKey = 'btn_end_trip';
          buttonColor = Colors.redAccent;
        });

        return;
      }

      if (statusOfTrip == TripStatus.onTrip) {
        await endTripNow();
      }
    } catch (e, stackTrace) {
      debugPrint('Trip status update error: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _showStatusError(
        'تغییر وضعیت سفر انجام نشد. دوباره تلاش کنید.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> endTripNow() async {
    if (_tripId.isEmpty) {
      return;
    }

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return LoadingDialog(
          messageText: 'ending_trip'.tr(),
        );
      },
    );

    try {
      final String finalFareAmount =
          (bidAmount != 'null' && bidAmount.isNotEmpty)
              ? bidAmount.toString()
              : fareAmount.toString();

      final currentStatus = await _getCurrentTripStatus();

      if (currentStatus != TripStatus.onTrip) {
        if (mounted) {
          Navigator.of(context).pop();
        }

        await _showStatusError(
          'پایان سفر انجام نشد؛ وضعیت فعلی: $currentStatus',
        );
        return;
      }

      await _tripRef.update({
        'fareAmount': finalFareAmount,
        'fare': double.tryParse(finalFareAmount) ?? 0,
        'status': TripStatus.completed,
        'completed_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _stopLocationUpdates();

      if (mounted) {
        Navigator.of(context).pop();
      }

      await saveFareAmountToDriverTotalEearning(finalFareAmount);

      if (!mounted) return;

      displayLoadingDialog(finalFareAmount);
    } catch (e, stackTrace) {
      debugPrint('End trip error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        Navigator.of(context).pop();
      }

      await _showStatusError(
        'پایان سفر انجام نشد. دوباره تلاش کنید.',
      );
    }
  }

  void displayLoadingDialog(String fareAmountValue) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PaymentDialog(
          fareAmount: fareAmountValue,
        );
      },
    );
  }

  Future<void> saveFareAmountToDriverTotalEearning(
    String fareAmountValue,
  ) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final DatabaseReference driverRef = FirebaseDatabase.instance
        .ref()
        .child('drivers')
        .child(currentUser.uid);

    final DataSnapshot snapshot =
        await driverRef.child('earnings').get();

    final double currentTripFare =
        double.tryParse(fareAmountValue) ?? 0.0;

    double previousTotalEarning = 0.0;

    if (snapshot.exists && snapshot.value != null) {
      previousTotalEarning =
          double.tryParse(snapshot.value.toString()) ?? 0.0;
    }

    final double newTotalEarning =
        previousTotalEarning + currentTripFare;

    await driverRef.update({
      'earnings': newTotalEarning.toStringAsFixed(2),
    });
  }

  @override
  void initState() {
    super.initState();

    saveDriverDataToTripInfo();
    getLiveLocationUpdatesOfDriver();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAccepted = statusOfTrip == TripStatus.accepted;

    final String navigationTitle = isAccepted
        ? 'مسیریابی به مبدأ مسافر'
        : 'مسیریابی به مقصد';

    return Directionality(
      textDirection: Directionality.of(context),
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'مدیریت سفر فعال',
              style: TextStyle(
                fontFamily: 'IranYekan',
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.primaryBrand,
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: AppColors.primaryBrand,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'مبدأ مسافر:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.newTripDetailsInfo
                                            ?.pickupAddress ??
                                        '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.flag_rounded,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'مقصد مسافر:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.newTripDetailsInfo
                                            ?.dropOffAddress ??
                                        '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isProcessing
                              ? null
                              : () {
                                  final dynamic targetLocation =
                                      isAccepted
                                          ? widget
                                              .newTripDetailsInfo
                                              ?.pickUpLatLng
                                          : widget
                                              .newTripDetailsInfo
                                              ?.dropOffLatLng;

                                  if (targetLocation != null &&
                                      targetLocation.latitude != null &&
                                      targetLocation.longitude != null) {
                                    _openExternalNavigationApp(
                                      targetLocation.latitude!,
                                      targetLocation.longitude!,
                                    );
                                  } else {
                                    commonMethods.displaySnackBar(
                                      'مختصات مقصد یافت نشد!',
                                      context,
                                    );
                                  }
                                },
                          icon: const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            navigationTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'IranYekan',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isProcessing
                                ? null
                                : _advanceTripStatus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: AppColors.buttonText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    buttonTitleKey.tr(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'IranYekan',
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : _cancelAcceptedTrip,
                            icon: const Icon(
                              Icons.cancel_outlined,
                            ),
                            label: const Text(
                              'لغو سفر',
                              style: TextStyle(
                                fontFamily: 'IranYekan',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(
                                color: Colors.redAccent,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  @override
  void dispose() {
    positionStreamNewTripPage?.cancel();
    positionStreamNewTripPage = null;
    super.dispose();
  }
}
