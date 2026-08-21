import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/trip_provider.dart'; 
import 'package:safir_drivers/utils/lang_helper.dart';

class TripsHistoryPage extends StatefulWidget {
  const TripsHistoryPage({super.key});

  @override
  _TripsHistoryPageState createState() => _TripsHistoryPageState();
}

class _TripsHistoryPageState extends State<TripsHistoryPage> {
  @override
  void initState() {
    super.initState();
    // دریافت اطلاعات سفرهای تکمیل‌شده راننده پس از مقداردهی اولیه صفحه
    Future.microtask(() =>
        Provider.of<TripProvider>(context, listen: false).getCompletedTrips());
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(context, 'trips_history_title'),
          style: const TextStyle(fontFamily: 'IranYekan', fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: tripProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF145A41)), // رنگ برند سفیر
              ),
            )
          : tripProvider.completedTrips.isEmpty
              ? Center(
                  child: Text(
                    tr(context, 'no_trips_history'),
                    style: const TextStyle(fontFamily: 'IranYekan', color: Colors.black54, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  itemCount: tripProvider.completedTrips.length,
                  itemBuilder: (context, index) {
                    var trip = tripProvider.completedTrips[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // سطر مبدأ و کرایه سفر
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/initial.png',
                                  height: 16,
                                  width: 16,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "${tr(context, 'pickup_label')}: ${trip["pickUpAddress"] ?? ''}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'IranYekan',
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // نمایش کرایه به افغانی
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF145A41).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${trip["fareAmount"] ?? 0} ${tr(context, 'currency_afg')}",
                                    style: const TextStyle(
                                      fontFamily: 'IranYekan',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF145A41),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // سطر مقصد
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/final.png',
                                  height: 16,
                                  width: 16,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "${tr(context, 'destination_label')}: ${trip["dropOffAddress"] ?? ''}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'IranYekan',
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}