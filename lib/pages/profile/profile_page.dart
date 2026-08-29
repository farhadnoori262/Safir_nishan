import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/profileUpdation/driver_main_info.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<RegistrationProvider>(context, listen: false)
            .retrieveCurrentDriverInfo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // 📌 کارت اطلاعات اصلی راننده
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: MediaQuery.of(context).size.width * 0.92,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          offset: Offset(0, 2),
                          blurRadius: 8.0,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // 🖼️ تصویر پروفایل راننده
                        SizedBox(
                          width: 80.0,
                          height: 80.0,
                          child: CachedNetworkImage(
                            imageUrl: driverPhoto,
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryBrand.withOpacity(0.2),
                                  width: 2,
                                ),
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBrand),
                              ),
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              child: Icon(
                                Icons.person,
                                size: 42,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // 📝 مشخصات متنی راننده
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                "$driverName $driverSecondName",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      driverPhone,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (driverEmail.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.email,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        driverEmail,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
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
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        address,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
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

              // 👤 گزینه اطلاعات کاربری
              _buildProfileMenuOption(
                context,
                icon: Icons.account_circle_outlined,
                title: 'profile_menu_account'.tr(),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverMainInfo(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // ⚙️ گزینه تنظیمات اپلیکیشن
              _buildProfileMenuOption(
                context,
                icon: Icons.settings_outlined,
                title: 'profile_menu_settings'.tr(),
                onTap: () {
                  _showPlaceholderPage(context, 'profile_menu_settings'.tr());
                },
              ),

              const SizedBox(height: 12),

              // 🎧 گزینه مرکز پشتیبانی
              _buildProfileMenuOption(
                context,
                icon: Icons.help_outline,
                title: 'profile_menu_support'.tr(),
                onTap: () {
                  _showPlaceholderPage(context, 'profile_menu_support'.tr());
                },
              ),
              
              const SizedBox(height: 80), // فاصله برای جلوگیری از همپوشانی با دکمه خروج
            ],
          ),
        ),
        // 🚪 دکمه خروج از حساب
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.red.shade700,
          onPressed: () async {
            await authProvider.signOut(context);
          },
          icon: const Icon(Icons.logout, color: Colors.white, size: 18),
          label: Text(
            'profile_logout'.tr(),
            style: const TextStyle(
              color: AppColors.buttonText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // 📄 متد کمکی جهت نمایش صفحات موقت
  void _showPlaceholderPage(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: true,
            backgroundColor: AppColors.cardBackground,
            elevation: 1,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
          ),
          body: Center(
            child: Text(
              "$title ${'coming_soon'.tr()}",
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 متد ساخت آیتم‌های منو
  Widget _buildProfileMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.cardBackground,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 1),
            blurRadius: 4.0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryBrand, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  isRtl ? Icons.chevron_left : Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
