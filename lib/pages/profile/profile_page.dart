import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safir_drivers/pages/profileUpdation/driver_main_info.dart'; 
import 'package:safir_drivers/providers/authentication_provider.dart'; // 👈 اصلاح نام پرووایدر به نسخه اصلی
import 'package:safir_drivers/providers/registration_provider.dart'; 
import 'package:safir_drivers/utils/lang_helper.dart'; 

import '../../global/global.dart';
import '../../widgets/rating_stars.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    Provider.of<RegistrationProvider>(context, listen: false)
        .retrieveCurrentDriverInfo();
  }

  @override
  Widget build(BuildContext context) {
    // اصلاح نام کلاس طبق فایل main.dart به AuthenticationProvider
    final authProvider = Provider.of<AuthenticationProvider>(context);

    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // کارت اطلاعات اصلی راننده
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 15),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    width: MediaQuery.of(context).size.width * 0.93,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 6.0,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // تصویر پروفایل راننده
                        Container(
                          width: 85.0,
                          height: 85.0,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: CachedNetworkImage(
                            imageUrl: driverPhoto,
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF145A41)),
                              ),
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              child: Icon(Icons.person, size: 45, color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // مشخصات متنی راننده
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                "$driverName $driverSecondName",
                                style: const TextStyle(fontFamily: 'IranYekan', fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.phone, size: 14, color: Colors.black54),
                                  const SizedBox(width: 6),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      driverPhone,
                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                              if (driverEmail.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    const Icon(Icons.email, size: 14, color: Colors.black54),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        driverEmail,
                                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    const Icon(Icons.location_on, size: 14, color: Colors.black54),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        address,
                                        style: const TextStyle(fontFamily: 'IranYekan', fontSize: 12, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              RatingStars(ratting: rating),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 10),

              // گزینه اطلاعات کاربری
              _buildProfileMenuOption(
                context,
                icon: Icons.account_circle_outlined,
                title: tr(context, 'profile_menu_account'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverMainInfo(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 14),

              // گزینه تنظیمات اپلیکیشن
              _buildProfileMenuOption(
                context,
                icon: Icons.settings_outlined,
                title: tr(context, 'profile_menu_settings'),
                onTap: () {
                  // صفحه موقت تنظیمات تا بعداً آن را بسازی
                  _showPlaceholderPage(context, tr(context, 'profile_menu_settings'));
                },
              ),
              
              const SizedBox(height: 14),

              // گزینه مرکز پشتیبانی
              _buildProfileMenuOption(
                context,
                icon: Icons.help_outline,
                title: tr(context, 'profile_menu_support'),
                onTap: () {
                  // صفحه موقت پشتیبانی تا بعداً آن را بسازی
                  _showPlaceholderPage(context, tr(context, 'profile_menu_support'));
                },
              ),
            ],
          ),
        ),
        // دکمه خروج از حساب
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.red.shade700,
          onPressed: () async {
            await authProvider.signOut(context);
          },
          icon: const Icon(Icons.logout, color: Colors.white, size: 18),
          label: Text(
            tr(context, 'profile_logout'),
            style: const TextStyle(fontFamily: 'IranYekan', color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // متد کمکی جهت نمایش صفحات موقت پشتیبانی و تنظیمات
  void _showPlaceholderPage(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title, style: const TextStyle(fontFamily: 'IranYekan', fontSize: 16)),
            centerTitle: true,
          ),
          body: Center(
            child: Text(
              "$title بزودی...",
              style: const TextStyle(fontFamily: 'IranYekan', fontSize: 18, color: Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  // متد ساخت منوهای متناسب با جهت زبان
  Widget _buildProfileMenuOption(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      width: MediaQuery.of(context).size.width * 0.93,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 1),
            blurRadius: 4.0,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF145A41)),
          title: Text(
            title,
            style: const TextStyle(fontFamily: 'IranYekan', fontSize: 14, fontWeight: FontWeight.w500),
          ),
          trailing: Icon(
            isRtl ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios, 
            size: 14, 
            color: Colors.black38
          ),
        ),
      ),
    );
  }
}
