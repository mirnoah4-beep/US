import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/language_provider.dart';
import '../models/moment_item.dart';
import '../theme/app_theme.dart';

class HeatCard extends StatefulWidget {
  final MomentItem item;
  final VoidCallback onTap;
  final bool isHighlighted;
  final VoidCallback? onHighlightDone;

  const HeatCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isHighlighted = false,
    this.onHighlightDone,
  });

  @override
  State<HeatCard> createState() => _HeatCardState();
}

class _HeatCardState extends State<HeatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // 3 pulses: scale 1.0 → 1.04 → 1.0 × 3
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
    ]).animate(_pulse);
    _pulse.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onHighlightDone?.call();
      }
    });
  }

  @override
  void didUpdateWidget(HeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // Pulse intensity 0→1 based on how far scale is from baseline
        final intensity = (_scale.value - 1.0) / 0.04;
        final borderColor = Color.lerp(
          widget.item.heatBorderColor,
          const Color(0xFFC1544A),
          intensity,
        )!;
        final glowOpacity = intensity * 0.22;

        return GestureDetector(
          onTap: widget.onTap,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.item.heatBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: glowOpacity > 0.01
                    ? [
                        BoxShadow(
                          color: const Color(0xFFC1544A)
                              .withValues(alpha: glowOpacity),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.item.icon, color: widget.item.heatIconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            context.watch<LanguageProvider>().s.momentTitle(widget.item.id),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            context.watch<LanguageProvider>().s.daysAgoLabel(widget.item.daysAgo),
            style: TextStyle(
              color: widget.item.heatTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
