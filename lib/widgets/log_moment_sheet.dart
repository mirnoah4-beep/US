import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/language_provider.dart';
import '../theme/app_theme.dart';

class LogMomentOption {
  final String id;
  final String label;
  final IconData icon;
  final bool parentModeOnly;

  const LogMomentOption({
    required this.id,
    required this.label,
    required this.icon,
    this.parentModeOnly = false,
  });
}

const _options = [
  LogMomentOption(id: 'date_night', label: 'Date night', icon: Icons.favorite_rounded),
  LogMomentOption(id: 'home_date', label: 'Home date', icon: Icons.home_rounded),
  LogMomentOption(id: 'walk', label: 'Walk together', icon: Icons.directions_walk_rounded),
  LogMomentOption(id: 'game', label: 'Game together', icon: Icons.sports_esports_rounded),
  LogMomentOption(id: 'phone_free', label: 'Phone-free talk', icon: Icons.chat_bubble_outline_rounded),
  LogMomentOption(id: 'no_kids', label: 'Time without kids', icon: Icons.child_friendly_rounded, parentModeOnly: true),
  LogMomentOption(id: 'custom', label: 'Custom moment', icon: Icons.add_circle_outline_rounded),
];

class LogMomentSheet extends StatefulWidget {
  final bool hasChildren;
  final Function(String momentId) onLog;

  const LogMomentSheet({
    super.key,
    required this.hasChildren,
    required this.onLog,
  });

  @override
  State<LogMomentSheet> createState() => _LogMomentSheetState();
}

class _LogMomentSheetState extends State<LogMomentSheet>
    with SingleTickerProviderStateMixin {
  String? _selected;
  bool _logged = false;
  late AnimationController _confirmController;

  @override
  void initState() {
    super.initState();
    _confirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  List<LogMomentOption> get _visibleOptions {
    if (widget.hasChildren) return _options;
    return _options.where((o) => !o.parentModeOnly).toList();
  }

  void _handleLog() {
    if (_selected == null) return;
    widget.onLog(_selected!);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) _confirmController.forward();
    setState(() => _logged = true);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: _logged ? _buildSuccess(context, s) : _buildPicker(s),
    );
  }

  Widget _buildSuccess(BuildContext context, s) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.accentGreenLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: AppTheme.accentGreen, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          s.logSuccess,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.logSuccessMsg,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, t, _) => Transform.translate(
                  offset: Offset(0, -t * 80),
                  child: Opacity(
                    opacity: t < 0.65 ? 1.0 : ((1.0 - t) / 0.35).clamp(0.0, 1.0),
                    child: Icon(
                      Icons.favorite_rounded,
                      color: const Color(0xFFC1544A),
                      size: 60.0 + t * 60.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPicker(s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          s.logTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.logSubtitle,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        ..._visibleOptions.map((opt) => _buildOption(opt, s)),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _confirmController,
          builder: (context, _) {
            final scale = _selected != null
                ? TweenSequence([
                    TweenSequenceItem(
                        tween: Tween(begin: 1.0, end: 0.96), weight: 30),
                    TweenSequenceItem(
                        tween: Tween(begin: 0.96, end: 1.03), weight: 40),
                    TweenSequenceItem(
                        tween: Tween(begin: 1.03, end: 1.0), weight: 30),
                  ]).transform(_confirmController.value)
                : 1.0;
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected != null ? _handleLog : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _selected != null ? AppTheme.accentRose : AppTheme.divider,
                    foregroundColor:
                        _selected != null ? AppTheme.white : AppTheme.textMuted,
                  ),
                  child: Text(s.logButton),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOption(LogMomentOption opt, s) {
    final isSelected = _selected == opt.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = opt.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentRoseLight : AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentRose : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              opt.icon,
              color: isSelected ? AppTheme.accentRose : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              s.logOptionLabel(opt.id),
              style: TextStyle(
                color: isSelected ? AppTheme.accentRose : AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accentRose, size: 20),
          ],
        ),
      ),
    );
  }
}
