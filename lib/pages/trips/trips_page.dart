import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/providers/trip_provider.dart'; 
import 'package:safir_drivers/utils/lang_helper.dart';
import 'trips_history_page.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  // 🎨 پالت رنگی رسمی برند سفیر
  static const Color brandPrimary = Color(0xFF145A41);   // رنگ اصلی برند
  static const Color btnPrimary = Color(0xFF1B7A57);     // دکمه اصلی
  static const Color cardBgLight = Color(0xFFEAF6F1);    // پس‌زمینه روشن کارت‌ها
  static const Color textOnBtn = Color(0xFFFFFFFF);      // متن روی دکمه

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<TripProvider>(context, listen: false)
            .getCurrentDriverTotalNumberOfTripsCompleted());
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);

    return Scaffold(
      backgroundColor: cardBgLight, // استفاده از پس‌زمینه کارت‌های پالت
      appBar: AppBar(
        title: Text(
          tr(context, 'trips_report_title'),
          style: const TextStyle(
            fontFamily: 'IranYekan', 
            fontWeight: FontWeight.bold, 
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: tripProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(brandPrimary),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(

                  children: [
                    // کارت نمایش مجموع سفرها
                    Center(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: brandPrimary.withOpacity(0.06),
                              offset: const Offset(0, 4),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Image.asset(
                                "assets/images/totaltrips.png",
                                width: 90,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                tr(context, 'total_completed_trips'),
                                style: TextStyle(
                                  fontFamily: 'IranYekan',
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tripProvider.currentDriverTotalTripsCompleted,
                                style: const TextStyle(
                                  fontFamily: 'IranYekan',
                                  color: brandPrimary,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // دکمه/کارت هدایت به تاریخچه سفرها
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (c) => const TripsHistoryPage()),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: btnPrimary, // دکمه اصلی بر اساس پالت
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: btnPrimary.withOpacity(0.25),
                                offset: const Offset(0, 6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Image.asset(
                                  "assets/images/tripscompleted.png",
                                  width: 100,
                                  color: textOnBtn,
                                  colorBlendMode: BlendMode.modulate,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      tr(context, 'view_trips_history'),
                                      style: const TextStyle(
                                        fontFamily: 'IranYekan',
                                        color: textOnBtn,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Directionality.of(context) == TextDirection.rtl
                                          ? Icons.arrow_back_ios_new
                                          : Icons.arrow_forward_ios,
                                      color: textOnBtn,
                                      size: 14,
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
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
