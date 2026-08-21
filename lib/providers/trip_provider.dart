import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class TripProvider with ChangeNotifier {
  String currentDriverTotalTripsCompleted = "0";
  bool isLoading = true;
  List<Map<String, dynamic>> completedTrips = [];

  // متد دریافت تعداد کل سفرهای موفق و پایان یافته راننده جاری
  Future<void> getCurrentDriverTotalNumberOfTripsCompleted() async {
    try {
      isLoading = true;
      notifyListeners();
      
      DatabaseReference tripRequestsRef =
          FirebaseDatabase.instance.ref().child("tripRequest");

      final snapshot = await tripRequestsRef.once();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (snapshot.snapshot.value != null && currentUid != null) {
        Map<dynamic, dynamic> allTripsMap = snapshot.snapshot.value as Map;
        int completedCount = 0;

        allTripsMap.forEach((key, value) {
          if (value is Map &&
              value["status"] == "ended" &&
              value["driverId"] == currentUid) {
            completedCount++;
          }
        });

        currentDriverTotalTripsCompleted = completedCount.toString();
      } else {
        currentDriverTotalTripsCompleted = "0";
      }
    } catch (error) {
      debugPrint("Error fetching completed trips count: $error");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // متد دریافت لیست کامل جزییات سفرهای تکمیل شده جهت نمایش در تاریخچه
  Future<void> getCompletedTrips() async {
    try {
      isLoading = true;
      notifyListeners();

      DatabaseReference tripRequestsRef =
          FirebaseDatabase.instance.ref().child("tripRequest");

      final snapshot = await tripRequestsRef.once();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      if (snapshot.snapshot.value != null && currentUid != null) {
        Map<dynamic, dynamic> allTripsMap = snapshot.snapshot.value as Map;
        List<Map<String, dynamic>> tempList = [];

        allTripsMap.forEach((key, value) {
          if (value is Map &&
              value["status"] == "ended" &&
              value["driverId"] == currentUid) {
            // تبدیل امن مپ دیتابیس به فرمت کست شده جهت استفاده در کدهای UI
            Map<String, dynamic> tripData = Map<String, dynamic>.from(value);
            tempList.add({"key": key, ...tripData});
          }
        });
        
        completedTrips = tempList;
      } else {
        completedTrips = [];
      }
    } catch (error) {
      debugPrint("Error fetching completed trips list: $error");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
