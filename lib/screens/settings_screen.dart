import 'package:flutter/material.dart';

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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildCoupleCard(),
            const SizedBox(height: 12),
            _buildSubscriptionBanner(),
            const SizedBox(height: 24),
            _buildSection1(),
            const SizedBox(height: 12),
            _buildSection2(),
            const SizedBox(height: 12),
            _buildSection3(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
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
        const Text(
          'Settings',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
      ],
    );
  }

  Widget _buildCoupleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Noah & Partner',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Together since 2020',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Edit',
              style: TextStyle(
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

  Widget _buildSubscriptionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    color: Color(0xFF7A2D12),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Unlock all features for your relationship',
                  style: TextStyle(
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

  Widget _buildSection1() {
    return _SettingsCard(
      children: [
        _NavRow(
          iconData: Icons.favorite_border,
          iconColor: const Color(0xFFC1544A),
          iconBg: const Color(0xFFFAECE7),
          title: 'Couple setup',
          subtitle: 'Partner profile and shared preferences',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CoupleSetupScreen()),
          ),
        ),
        const _RowDivider(),
        _ToggleRow(
          iconData: Icons.child_care,
          iconColor: const Color(0xFF854F0B),
          iconBg: const Color(0xFFFAEEDA),
          title: 'Parent mode',
          subtitle: 'Child-friendly ideas and reminders',
          value: _parentMode,
          onChanged: (v) => setState(() => _parentMode = v),
        ),
        const _RowDivider(),
        const _NavRow(
          iconData: Icons.notifications_none,
          iconColor: Color(0xFFC1544A),
          iconBg: Color(0xFFFAECE7),
          title: 'Reminders',
          subtitle: 'Gentle nudges for quality time',
        ),
      ],
    );
  }

  Widget _buildSection2() {
    return _SettingsCard(
      children: [
        _ToggleRow(
          iconData: Icons.bedtime_outlined,
          iconColor: const Color(0xFF5F5E5A),
          iconBg: const Color(0xFFF1EFE8),
          title: 'Quiet hours',
          subtitle: 'Pause notifications during sleep',
          value: _quietHours,
          onChanged: (v) => setState(() => _quietHours = v),
        ),
        const _RowDivider(),
        const _NavRow(
          iconData: Icons.lock_outline,
          iconColor: Color(0xFF5F5E5A),
          iconBg: Color(0xFFF1EFE8),
          title: 'Privacy',
          subtitle: 'Control what is saved and shared',
        ),
        const _RowDivider(),
        const _NavRow(
          iconData: Icons.palette_outlined,
          iconColor: Color(0xFF5F5E5A),
          iconBg: Color(0xFFF1EFE8),
          title: 'Appearance',
          subtitle: 'Theme and display settings',
        ),
        const _RowDivider(),
        const _NavRow(
          iconData: Icons.language,
          iconColor: Color(0xFF5F5E5A),
          iconBg: Color(0xFFF1EFE8),
          title: 'Language',
          subtitle: 'App language and region',
        ),
      ],
    );
  }

  Widget _buildSection3() {
    return _SettingsCard(
      children: [
        const _NavRow(
          iconData: Icons.logout,
          iconColor: Color(0xFFA32D2D),
          iconBg: Color(0xFFFCEBEB),
          title: 'Sign out',
          subtitle: 'Sign out of your account',
        ),
        const _RowDivider(),
        const _NavRow(
          iconData: Icons.workspace_premium_outlined,
          iconColor: Color(0xFFC1544A),
          iconBg: Colors.white,
          title: 'Subscription',
          subtitle: 'Manage your plan',
        ),
      ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFFC1544A),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFE0D9D0),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
