import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../theme/app_theme.dart';

class RelationshipBatteryCard extends StatelessWidget {
  final int percent;
  final String statusLine;
  final String message;

  const RelationshipBatteryCard({
    super.key,
    required this.percent,
    required this.statusLine,
    required this.message,
  });

  Color _pillColor(int pct) {
    if (pct >= 65) return AppTheme.accentGreen;
    return AppTheme.warningAmber;
  }

  Color _pillBg(int pct) {
    if (pct >= 65) return AppTheme.accentGreenLight;
    return AppTheme.warningAmberLight;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final pct = percent.clamp(0, 100);
    final progress = pct / 100.0;
    final mood = s.batteryMood(pct);
    final pillLabel = s.batteryPillLabel(pct);
    final pillColor = _pillColor(pct);
    final pillBg = _pillBg(pct);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_border, color: AppTheme.accentRose, size: 15),
              const SizedBox(width: 6),
              Text(
                s.batteryTitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _OverlappingAvatars(),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  mood,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Georgia',
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(
                    color: pillColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress),
            duration:
                reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: AppTheme.accentRoseLight,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.accentRose),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlappingAvatars extends StatelessWidget {
  const _OverlappingAvatars();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final userAvatarUrl = appState.userAvatarUrl;
    final partnerAvatarUrl = appState.partnerAvatarUrl;
    final myInitial = appState.displayName.isNotEmpty
        ? appState.displayName[0].toUpperCase()
        : '?';
    final partnerInitial = appState.partnerName.isNotEmpty
        ? appState.partnerName[0].toUpperCase()
        : '?';

    const diameter = 52.0;
    const overlap = 16.0;
    const totalWidth = diameter * 2 - overlap;

    return SizedBox(
      width: totalWidth,
      height: diameter,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _Avatar(
              label: myInitial,
              background: const Color(0xFFEBD2D2),
              foreground: AppTheme.accentRose,
              diameter: diameter,
              imageUrl: userAvatarUrl,
            ),
          ),
          Positioned(
            left: diameter - overlap,
            child: _Avatar(
              label: partnerInitial,
              background: const Color(0xFFD8E9DA),
              foreground: AppTheme.accentGreen,
              diameter: diameter,
              imageUrl: partnerAvatarUrl,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final double diameter;
  final String? imageUrl;

  const _Avatar({
    required this.label,
    required this.background,
    required this.foreground,
    required this.diameter,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: diameter * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                width: diameter,
                height: diameter,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}
