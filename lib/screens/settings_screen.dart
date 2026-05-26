import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/language_provider.dart';
import '../theme/app_theme.dart';
import 'couple_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _parentMode = false;
  bool _quietHours = false;

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
            _buildCoupleCard(s),
            const SizedBox(height: 12),
            _buildSubscriptionBanner(s),
            const SizedBox(height: 24),
            _buildSection1(s),
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

  Widget _buildCoupleCard(s) {
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
                    child: const Icon(
                      Icons.person,
                      size: 20,
                      color: Color(0xFFC1544A),
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
                const Text(
                  'Noah & Partner',
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

  Widget _buildSection1(s) {
    return _SettingsCard(
      children: [
        _ToggleRow(
          iconData: Icons.child_care,
          iconColor: const Color(0xFF854F0B),
          iconBg: const Color(0xFFFAEEDA),
          title: s.settingsParentMode,
          subtitle: s.settingsParentModeSub,
          value: _parentMode,
          onChanged: (v) => setState(() => _parentMode = v),
        ),
        const _RowDivider(),
        _NavRow(
          iconData: Icons.notifications_none,
          iconColor: const Color(0xFFC1544A),
          iconBg: const Color(0xFFFAECE7),
          title: s.settingsReminders,
          subtitle: s.settingsRemindersSub,
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
          onTap: () => _showLanguagePicker(context),
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

  void _showLanguagePicker(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final s = langProvider.s;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguagePickerSheet(
        title: s.settingsLanguagePickerTitle,
        isNorwegian: langProvider.isNorwegian,
        onSelect: (isNo) => langProvider.setNorwegian(isNo),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  final String title;
  final bool isNorwegian;
  final ValueChanged<bool> onSelect;

  const _LanguagePickerSheet({
    required this.title,
    required this.isNorwegian,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C2420),
            ),
          ),
          const SizedBox(height: 16),
          _LangOption(
            label: 'Norsk',
            selected: isNorwegian,
            onTap: () {
              onSelect(true);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          _LangOption(
            label: 'English',
            selected: !isNorwegian,
            onTap: () {
              onSelect(false);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangOption(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFAECE7)
              : const Color(0xFFF8F6F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFC1544A)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFFC1544A)
                    : AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFFC1544A), size: 20),
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
