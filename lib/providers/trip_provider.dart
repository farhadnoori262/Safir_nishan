import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class TripProvider with ChangeNotifier {
  String currentDriverTotalTripsCompleted = "0";
  bool isLoading = false;
  List<Map<String, dynamic>> completedTrips = [];

  final DatabaseReference _tripRequestsRef =
      FirebaseDatabase.instance.ref().child("tripRequest");

  // دریافت تمام سفرهای تکمیل شده در یک کوئری بهینه‌شده
  Future<void> fetchCompletedTrips() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    try {
      isLoading = true;
      notifyListeners();

      // فیلتر کردن سفرها بر اساس driverId مستقیم در سمت سرور
      final querySnapshot = await _tripRequestsRef
          .orderByChild("driverId")
          .equalTo(currentUid)
          .once();

      final dataMap = querySnapshot.snapshot.value;

      if (dataMap != null && dataMap is Map) {
        List<Map<String, dynamic>> tempList = [];

        dataMap.forEach((key, value) {
          if (value is Map && value["status"] == "ended") {
            Map<String, dynamic> tripData = Map<String, dynamic>.from(value);
            tempList.add({"key": key, ...tripData});
          }
        });

        completedTrips = tempList;
        currentDriverTotalTripsCompleted = tempList.length.toString();
      } else {
        completedTrips = [];
        currentDriverTotalTripsCompleted = "0";
      }
    } catch (error) {
      debugPrint("Error fetching completed trips: $error");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
