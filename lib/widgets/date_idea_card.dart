import 'package:flutter/material.dart';
import '../models/date_idea.dart';
import '../theme/app_theme.dart';

class DateIdeaCard extends StatelessWidget {
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.cardBeige,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(idea.icon, color: AppTheme.accentRose, size: 24),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onFavorite,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    idea.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(idea.isFavorite),
                    color: idea.isFavorite ? AppTheme.accentRose : AppTheme.textMuted,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            idea.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cardBeige,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  idea.duration,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentRoseLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  idea.categoryLabel,
                  style: const TextStyle(
                    color: AppTheme.accentRose,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onSuggest,
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.cardBeige,
                foregroundColor: AppTheme.accentRose,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text(
                'Suggest',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
