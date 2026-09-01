import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:safir_drivers/pages/profileUpdation/driver_main_info.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/providers/registration_provider.dart';
import 'package:safir_drivers/utils/app_colors.dart';

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
        body: Consumer<RegistrationProvider>(
          builder: (context, regProvider, child) {
            // دریافت اطلاعات زنده راننده از Provider
            final driver = regProvider.driverInformation;

            String name = (driver?.name != null && driver!.name!.isNotEmpty)
                ? "${driver.name} ${driver.secondName ?? ''}".trim()
                : "نام ثبت‌نشده";
            String phone = driver?.phone ?? "---";
            String email = driver?.email ?? "";
            String addressStr = driver?.address ?? "";
            String photo = driver?.photo ?? "";
            double ratingVal = double.tryParse(driver?.rating ?? "5.0") ?? 5.0;

            return SingleChildScrollView(
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
                              child: photo.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: photo,
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
                                      errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
                                    )
                                  : _buildAvatarPlaceholder(),
                            ),
                            const SizedBox(width: 14),
                            // 📝 مشخصات متنی راننده
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    name,
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
                                          phone,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (email.isNotEmpty) ...[
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
                                            email,
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
                                  if (addressStr.isNotEmpty) ...[
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
                                            addressStr,
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
                                  RatingStars(ratting: ratingVal.toString()),

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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
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

                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
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

  Widget _buildAvatarPlaceholder() {
    return CircleAvatar(
      backgroundColor: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: 42,
        color: Colors.grey.shade500,
      ),
    );
  }

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

// 🌐 صفحه تنظیمات و انتخاب زبان (دری، پشتو، انگلیسی)
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Locale _selectedLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLocale = context.locale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'profile_menu_settings'.tr(),
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "انتخاب زبان / ژبه وټاکئ / Select Language",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // گزینه زبان دری / فارسی
            _buildLanguageOption(
              title: "دری (Dari)",
              locale: const Locale('fa', 'AF'),
            ),

            // گزینه زبان پشتو
            _buildLanguageOption(
              title: "پښتو (Pashto)",
              locale: const Locale('ps', 'AF'),
            ),

            // گزینه زبان انگلیسی
            _buildLanguageOption(
              title: "English",
              locale: const Locale('en', 'US'),
            ),

            const Spacer(),

            // دکمه تایید تغییر زبان
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await context.setLocale(_selectedLocale);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("زبان با موفقیت تغییر کرد"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "تایید / تایید / Confirm",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({required String title, required Locale locale}) {
    bool isSelected = _selectedLocale.languageCode == locale.languageCode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primaryBrand : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: AppColors.primaryBrand)
            : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
        onTap: () {
          setState(() {
            _selectedLocale = locale;
          });
        },
      ),
    );
  }
}
