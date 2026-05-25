import 'package:flutter/material.dart';

import '../models/date_idea.dart';
import '../theme/app_theme.dart';

class DateIdeaCard extends StatefulWidget {
  final DateIdea idea;
  final VoidCallback onFavorite;
  final VoidCallback onSuggest;

  const DateIdeaCard({
    super.key,
    required this.idea,
    required this.onFavorite,
    required this.onSuggest,
  });

  @override
  State<DateIdeaCard> createState() => _DateIdeaCardState();
}

class _DateIdeaCardState extends State<DateIdeaCard>
    with TickerProviderStateMixin {
  bool _sent = false;

  // Heart animations
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  late AnimationController _burstController;

  // Send button animations
  late AnimationController _sendController;
  late Animation<double> _sendScale;
  late Animation<Color?> _sendBg;
  late Animation<double> _sendRotation;

  @override
  void initState() {
    super.initState();

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_heartController);

    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

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
      begin: const Color(0xFFC1544A),
      end: const Color(0xFF3B6D11),
    ).animate(CurvedAnimation(
      parent: _sendController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    ));
    _sendRotation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.18),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.18, end: 0.0),
        weight: 70,
      ),
    ]).animate(_sendController);
  }

  @override
  void dispose() {
    _heartController.dispose();
    _burstController.dispose();
    _sendController.dispose();
    super.dispose();
  }

  void _handleHeartTap() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) {
      _heartController.forward(from: 0);
      if (!widget.idea.isFavorite) {
        _burstController.forward(from: 0);
      }
    }
    widget.onFavorite();
  }

  void _handleSendTap() {
    if (_sent) return;
    setState(() => _sent = true);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) {
      _sendController.forward(from: 0);
    }
    widget.onSuggest();
  }

  List<Widget> _burstHearts(double t) {
    const offsets = [Offset(-22, -22), Offset(0, -30), Offset(22, -22)];
    return List.generate(3, (i) => Positioned(
      left: 24 + offsets[i].dx * t - 5,
      top: 24 + offsets[i].dy * t - 5,
      child: Opacity(
        opacity: (1.0 - t).clamp(0.0, 1.0),
        child: const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFC1544A),
          size: 10,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.cardBeige,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              widget.idea.icon,
              color: AppTheme.accentRose,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.idea.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Tag(
                      label: widget.idea.duration,
                      bg: AppTheme.cardBeige,
                      color: AppTheme.textSecondary,
                    ),
                    _Tag(
                      label: widget.idea.categoryLabel,
                      bg: AppTheme.accentRoseLight,
                      color: AppTheme.accentRose,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Heart with burst overlay
              SizedBox(
                width: 48,
                height: 48,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_heartController, _burstController]),
                  builder: (context, _) {
                    final burstT = _burstController.value;
                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (_burstController.isAnimating)
                          ..._burstHearts(burstT),
                        GestureDetector(
                          onTap: _handleHeartTap,
                          child: Transform.scale(
                            scale: _heartScale.value,
                            child: Icon(
                              widget.idea.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: widget.idea.isFavorite
                                  ? AppTheme.accentRose
                                  : const Color(0xFFE0D9D0),
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Animated send button
              AnimatedBuilder(
                animation: _sendController,
                builder: (context, _) {
                  final bg = _sent
                      ? (_sendController.isAnimating
                          ? _sendBg.value!
                          : const Color(0xFF3B6D11))
                      : const Color(0xFFC1544A);
                  return Transform.scale(
                    scale: _sendController.isAnimating ? _sendScale.value : 1.0,
                    child: Transform.rotate(
                      angle: _sendController.isAnimating ? _sendRotation.value : 0,
                      child: GestureDetector(
                        onTap: _handleSendTap,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sent ? Icons.check_rounded : Icons.send_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sent ? 'Sent to S!' : 'Send',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color bg;
  final Color color;

  const _Tag({
    required this.label,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
