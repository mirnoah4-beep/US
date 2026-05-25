import 'package:flutter/material.dart';
import '../models/moment_item.dart';
import '../theme/app_theme.dart';
import 'confetti_overlay.dart';

class ActivitySheet extends StatefulWidget {
  final MomentItem item;
  final VoidCallback onLog;

  const ActivitySheet({super.key, required this.item, required this.onLog});

  @override
  State<ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<ActivitySheet>
    with SingleTickerProviderStateMixin {
  bool _ideaSent = false;
  bool _logged = false;
  bool _confettiActive = false;

  // Send idea button animations
  late AnimationController _sendController;
  late Animation<double> _sendScale;
  late Animation<Color?> _sendBg;
  late Animation<double> _sendRotation;

  @override
  void initState() {
    super.initState();
    _sendController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _sendScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.95)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 37.5,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 37.5,
      ),
    ]).animate(_sendController);
    _sendBg = ColorTween(
      begin: AppTheme.accentRose,
      end: const Color(0xFF3B6D11),
    ).animate(CurvedAnimation(
      parent: _sendController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    ));
    _sendRotation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.18), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.18, end: 0.0), weight: 70),
    ]).animate(_sendController);
  }

  @override
  void dispose() {
    _sendController.dispose();
    super.dispose();
  }

  void _sendIdea() {
    if (_ideaSent) return;
    setState(() {
      _ideaSent = true;
    });
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) _sendController.forward(from: 0);
  }

  void _logMoment() {
    widget.onLog();
    setState(() {
      _logged = true;
      _confettiActive = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConfettiBurst(
      active: _confettiActive,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(context).viewInsets.bottom + 36,
        ),
        child: _logged ? _buildSuccess(context) : _buildContent(),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppTheme.heatGreenBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppTheme.heatGreenText, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Logged!',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Small moments keep love strong.',
          textAlign: TextAlign.center,
          style: TextStyle(
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
                    opacity: t < 0.65
                        ? 1.0
                        : ((1.0 - t) / 0.35).clamp(0.0, 1.0),
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

  Widget _buildContent() {
    final item = widget.item;
    final hasIdea = item.ideaSuggestion != null;

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

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: item.heatBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: item.heatBorderColor, width: 1.5),
              ),
              child: Icon(item.icon, color: item.heatTextColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Georgia',
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.daysAgoLabel,
                    style: TextStyle(
                      color: item.heatTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(item: item),
          ],
        ),

        if (hasIdea) ...[
          const SizedBox(height: 20),
          _IdeaCard(item: item),
        ],

        const SizedBox(height: 24),

        if (hasIdea)
          AnimatedBuilder(
            animation: _sendController,
            builder: (context, _) {
              final bg = _ideaSent
                  ? (_sendController.isAnimating
                      ? _sendBg.value!
                      : const Color(0xFF3B6D11))
                  : AppTheme.accentRose;
              final fg = _ideaSent
                  ? (_sendController.isAnimating
                      ? Colors.white
                      : AppTheme.heatGreenText)
                  : AppTheme.white;
              return Transform.scale(
                scale:
                    _sendController.isAnimating ? _sendScale.value : 1.0,
                child: Transform.rotate(
                  angle: _sendController.isAnimating
                      ? _sendRotation.value
                      : 0,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _ideaSent ? null : _sendIdea,
                      icon: Icon(
                        _ideaSent ? Icons.check_rounded : Icons.send_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _ideaSent ? 'Sent to S!' : 'Send to S',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bg,
                        foregroundColor: fg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _logMoment,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text(
              'We did this!',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.divider, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MomentItem item;
  const _StatusBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final isGood = item.isAllGood;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: item.heatBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.heatBorderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGood ? Icons.check_circle_rounded : Icons.calendar_month_rounded,
            size: 13,
            color: item.heatTextColor,
          ),
          const SizedBox(width: 4),
          Text(
            isGood ? 'All good' : 'Time for this again?',
            style: TextStyle(
              color: item.heatTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  final MomentItem item;
  const _IdeaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final idea = item.ideaSuggestion!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.heatBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.heatBorderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: item.heatTextColor),
              const SizedBox(width: 6),
              Text(
                'Idea for you',
                style: TextStyle(
                  color: item.heatTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            idea.text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: item.heatBorderColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              idea.duration,
              style: TextStyle(
                color: item.heatTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
