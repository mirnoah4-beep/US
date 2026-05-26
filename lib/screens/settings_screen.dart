import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../theme/app_theme.dart';
import 'couple_setup_screen.dart';
import 'lifestyle_setup_screen.dart';
import 'reminders_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _parentMode = false;
  bool _quietHours = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    // TODO: replace with Firestore when backend ready
    final prefs = await SharedPreferences.getInstance();
    final parentMode = prefs.getBool('parentMode') ?? false;
    final savedName = prefs.getString('userName') ?? '';
    if (mounted) {
      setState(() => _parentMode = parentMode);
      final appState = context.read<AppState>();
      appState.setHasChildren(parentMode);
      if (savedName.isNotEmpty) appState.updateDisplayName(savedName);
    }
  }

  Future<void> _saveParentMode(bool value) async {
    setState(() => _parentMode = value);
    // TODO: replace with Firestore when backend ready
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('parentMode', value);
    if (mounted) context.read<AppState>().setHasChildren(value);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            _buildHeader(context, s),
            const SizedBox(height: 24),
            _buildCoupleCard(context, s),
            const SizedBox(height: 12),
            _buildSubscriptionBanner(s),
            const SizedBox(height: 24),
            _sectionLabel(s.settingsDittForhold),
            const SizedBox(height: 8),
            _buildDittForholdSection(context, s),
            const SizedBox(height: 12),
            _buildSection1(context, s),
            const SizedBox(height: 12),
            _buildSection2(context, s),
            const SizedBox(height: 12),
            _buildSection3(s),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, s) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border:
                  Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: Color(0xFF888888),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          s.settingsTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }

  Widget _buildCoupleCard(BuildContext context, s) {
    final appState = context.watch<AppState>();
    final displayName = appState.displayName;
    final avatarPath = appState.userAvatarPath;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 36,
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAECE7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipOval(
                      child: avatarPath != null &&
                              File(avatarPath).existsSync()
                          ? Image.file(
                              File(avatarPath),
                              fit: BoxFit.cover,
                              width: 36,
                              height: 36,
                            )
                          : const Icon(
                              Icons.person,
                              size: 20,
                              color: Color(0xFFC1544A),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEEDA),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 20,
                      color: Color(0xFF854F0B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$displayName & Partner',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  s.settingsTogether,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CoupleSetupScreen()),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              s.settingsEdit,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC1544A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner(s) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9E8E1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              size: 20,
              color: Color(0xFFC1544A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.settingsUpgrade,
                  style: const TextStyle(
                    color: Color(0xFF7A2D12),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  s.settingsUnlock,
                  style: const TextStyle(
                    color: Color(0xFF993C1D),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: Color(0xFF993C1D),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFFB4B2A9),
        letterSpacing: 0.77,
      ),
    );
  }

  Widget _buildDittForholdSection(BuildContext context, s) {
    return _SettingsCard(
      children: [
        _NavRow(
          iconData: Icons.tune_outlined,
          iconColor: const Color(0xFF534AB7),
          iconBg: const Color(0xFFEEEDFE),
          title: s.lifestyleTitle,
          subtitle: s.settingsLifestyleSub,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const LifestyleSetupScreen(isFirstTime: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection1(BuildContext context, s) {
    return _SettingsCard(
      children: [
        _ToggleRow(
          iconData: Icons.child_care,
          iconColor: const Color(0xFF854F0B),
          iconBg: const Color(0xFFFAEEDA),
          title: s.settingsParentMode,
          subtitle: s.settingsParentModeSub,
          value: _parentMode,
          onChanged: _saveParentMode,
        ),
        const _RowDivider(),
        _NavRow(
          iconData: Icons.notifications_none,
          iconColor: const Color(0xFFC1544A),
          iconBg: const Color(0xFFFAECE7),
          title: s.settingsReminders,
          subtitle: s.settingsRemindersSub,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemindersScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildSection2(BuildContext context, s) {
    return _SettingsCard(
      children: [
        _ToggleRow(
          iconData: Icons.bedtime_outlined,
          iconColor: const Color(0xFF5F5E5A),
          iconBg: const Color(0xFFF1EFE8),
          title: s.settingsQuietHours,
          subtitle: s.settingsQuietHoursSub,
          value: _quietHours,
          onChanged: (v) => setState(() => _quietHours = v),
        ),
        const _RowDivider(),
        _NavRow(
          iconData: Icons.lock_outline,
          iconColor: const Color(0xFF5F5E5A),
          iconBg: const Color(0xFFF1EFE8),
          title: s.settingsPrivacy,
          subtitle: s.settingsPrivacySub,
        ),
        const _RowDivider(),
        _NavRow(
          iconData: Icons.palette_outlined,
          iconColor: const Color(0xFF5F5E5A),
          iconBg: const Color(0xFFF1EFE8),
          title: s.settingsAppearance,
          subtitle: s.settingsAppearanceSub,
        ),
        const _RowDivider(),
        _NavRow(
          iconData: Icons.language,
          iconColor: const Color(0xFF5F5E5A),
          iconBg: const Color(0xFFF1EFE8),
          title: s.settingsLanguage,
          subtitle: s.settingsLanguageSub,
          onTap: () => _showLanguageSheet(context),
        ),
      ],
    );
  }

  Widget _buildSection3(s) {
    return _SettingsCard(
      children: [
        _NavRow(
          iconData: Icons.logout,
          iconColor: const Color(0xFFA32D2D),
          iconBg: const Color(0xFFFCEBEB),
          title: s.settingsSignOut,
          subtitle: s.settingsSignOutSub,
        ),
        const _RowDivider(),
        _NavRow(
          iconData: Icons.workspace_premium_outlined,
          iconColor: const Color(0xFFC1544A),
          iconBg: Colors.white,
          title: s.settingsSubscription,
          subtitle: s.settingsSubscriptionSub,
        ),
      ],
    );
  }

  void _showLanguageSheet(BuildContext context) {
    final s = context.read<LanguageProvider>().s;
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isNorwegian = context.read<LanguageProvider>().isNorwegian;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F4),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3D1C7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.settingsLanguage,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _languageOption(ctx, 'Norsk', true, isNorwegian),
              const SizedBox(height: 8),
              _languageOption(ctx, 'English', false, isNorwegian),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _languageOption(BuildContext ctx, String label, bool norwegian, bool isNorwegian) {
    final isSelected = norwegian == isNorwegian;
    return GestureDetector(
      onTap: () {
        context.read<LanguageProvider>().setNorwegian(norwegian);
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAECE7) : Colors.white,
          border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.language_outlined,
              color: isSelected ? const Color(0xFFC1544A) : const Color(0xFF888780),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF4A1B0C) : const Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFC1544A), size: 20),
          ],
        ),
      ),
    );
  }

}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFF0ECE6),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData iconData;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _NavRow({
    required this.iconData,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 13),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFFD3D1C7),
        size: 18,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData iconData;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.iconData,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 13),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFFC1544A),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFE0D9D0),
        trackOutlineColor:
            WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
