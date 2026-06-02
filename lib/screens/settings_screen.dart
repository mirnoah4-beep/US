import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'lifestyle_setup_screen.dart';
import 'our_relationship_screen.dart';
import 'profile_screen.dart';
import 'reminders_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _quietHours = false;

  Future<void> _saveParentMode(bool value) async {
    final appState = context.read<AppState>();
    appState.setHasChildren(value);
    final coupleId = appState.coupleId;
    if (coupleId.isNotEmpty) {
      FirestoreService.updateSettings(coupleId, {'parentMode': value})
          .catchError((_) {});
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFFFAF7F4),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout,
                  color: Color(0xFFA32D2D),
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Logg ut',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Du må logge inn igjen for å bruke appen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888780),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA32D2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Logg ut',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5F5E5A),
                    side: const BorderSide(color: Color(0xFFE0D9D0)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Avbryt',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final s = context.read<LanguageProvider>().s;
    final appState = context.read<AppState>();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final coupleId = appState.coupleId;
    final rootNav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(s: s),
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context, // ignore: use_build_context_synchronously
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    await StorageService.deleteUserFiles(uid);
    try {
      await FirestoreService.deleteUserData(uid, coupleId.isNotEmpty ? coupleId : null);
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          rootNav.pop();
          if (!mounted) return;
          final reauthed = await _reauth(context, user, s); // ignore: use_build_context_synchronously
          if (!reauthed || !mounted) return;
          showDialog<void>(
            context: context, // ignore: use_build_context_synchronously
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
          try {
            await user.delete();
          } catch (_) {
            rootNav.pop();
            messenger.showSnackBar(SnackBar(content: Text(s.deleteAccountError)));
            return;
          }
        }
      }
    }

    rootNav.pop();
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  Future<bool> _reauth(BuildContext context, User user, dynamic s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s.deleteAccountReauthTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          s.deleteAccountReauthBody,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF888780),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5F5E5A),
                    side: const BorderSide(color: Color(0xFFE0D9D0)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(s.deleteAccountCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA32D2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(s.deleteAccountReauthButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      final providerId = user.providerData
          .firstWhere(
            (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
            orElse: () => user.providerData.first,
          )
          .providerId;

      if (providerId == 'google.com') {
        final googleSignIn = GoogleSignIn(clientId: '196627223703-a8odmf7vek1bmff7k6vrcin33motbks5.apps.googleusercontent.com');
        await googleSignIn.signOut();
        final account = await googleSignIn.signIn();
        if (account == null) return false;
        final auth = await account.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final oAuth = OAuthProvider('apple.com').credential(
          idToken: credential.identityToken,
          accessToken: credential.authorizationCode,
        );
        await user.reauthenticateWithCredential(oAuth);
      }
      return true;
    } catch (_) {
      return false;
    }
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
            _sectionLabel(s.settingsKonto),
            const SizedBox(height: 8),
            _buildKontoSection(context, s),
            const SizedBox(height: 24),
            _sectionLabel(s.settingsDittForhold),
            const SizedBox(height: 8),
            _buildDittForholdSection(context, s),
            const SizedBox(height: 12),
            _buildSection1(context, s),
            const SizedBox(height: 12),
            _buildSection2(context, s),
            const SizedBox(height: 12),
            _buildSection3(context, s),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => _deleteAccount(context),
                child: Text(
                  s.settingsDeleteAccount,
                  style: const TextStyle(
                    color: Color(0xFFA32D2D),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
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
                color: AppTheme.textSubtle,
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
    final avatarUrl = appState.userAvatarUrl;
    final partnerName = appState.partnerName;
    final partnerAvatarUrl = appState.partnerAvatarUrl;
    final partnerInitial =
        partnerName.isNotEmpty ? partnerName[0].toUpperCase() : null;
    final hasPartner = appState.coupleId.isNotEmpty;
    final togetherSince = appState.togetherSince;
    final subtitleText = togetherSince != null
        ? s.settingsTogetherSince(s.coupleDate(togetherSince))
        : s.ourRelationshipNoDate;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: hasPartner
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OurRelationshipScreen()),
                  )
              : null,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            child: avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    width: 36,
                                    height: 36,
                                    placeholder: (_, _) => const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Color(0xFFC1544A),
                                    ),
                                    errorWidget: (_, _, _) => const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Color(0xFFC1544A),
                                    ),
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
                          child: ClipOval(
                            child: partnerAvatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: partnerAvatarUrl,
                                    fit: BoxFit.cover,
                                    width: 36,
                                    height: 36,
                                    placeholder: (_, _) =>
                                        _partnerFallback(partnerInitial),
                                    errorWidget: (_, _, _) =>
                                        _partnerFallback(partnerInitial),
                                  )
                                : _partnerFallback(partnerInitial),
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
                        partnerName.isEmpty
                            ? displayName
                            : '$displayName & $partnerName',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasPartner)
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFD3D1C7),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
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

  Widget _buildKontoSection(BuildContext context, s) {
    return _SettingsCard(
      children: [
        _NavRow(
          iconData: Icons.person_outline,
          iconColor: const Color(0xFFC1544A),
          iconBg: const Color(0xFFFAECE7),
          title: s.settingsProfile,
          subtitle: s.settingsProfileSub,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        ),
      ],
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
          value: context.watch<AppState>().hasChildren,
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

  Widget _buildSection3(BuildContext context, s) {
    return _SettingsCard(
      children: [
        _NavRow(
          iconData: Icons.logout,
          iconColor: const Color(0xFFA32D2D),
          iconBg: const Color(0xFFFCEBEB),
          title: s.settingsSignOut,
          subtitle: s.settingsSignOutSub,
          onTap: () => _signOut(context),
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

  Widget _partnerFallback(String? initial) {
    if (initial != null) {
      return Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF854F0B),
          ),
        ),
      );
    }
    return const Icon(Icons.person, size: 20, color: Color(0xFF854F0B));
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

class _DeleteAccountDialog extends StatelessWidget {
  final dynamic s;
  const _DeleteAccountDialog({required this.s});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        s.deleteAccountTitle,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1A1A1A),
          letterSpacing: -0.3,
        ),
      ),
      content: Text(
        s.deleteAccountBody,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF888780),
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5F5E5A),
                  side: const BorderSide(color: Color(0xFFE0D9D0)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(s.deleteAccountCancel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA32D2D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(s.deleteAccountConfirm),
              ),
            ),
          ],
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
