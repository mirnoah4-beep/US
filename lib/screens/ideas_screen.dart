import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/date_idea.dart';
import '../models/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/date_idea_card.dart';

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  IdeaCategory? _selectedCategory;

  static const _chipCategories = [
    IdeaCategory.tenMin,
    IdeaCategory.thirtyAtHome,
    IdeaCategory.oneHourOut,
    IdeaCategory.babysitterNight,
    IdeaCategory.parentMode,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.watch<LanguageProvider>().s;
    final allIdeas = state.visibleIdeas;
    final filtered = _selectedCategory == null
        ? allIdeas
        : allIdeas.where((i) => i.category == _selectedCategory).toList();

    final chipLabels = [
      s.ideasChip10min,
      s.ideasChip30home,
      s.ideasChip1hour,
      s.ideasChipBabysitter,
      s.ideasChipParent,
    ];

    final allChips = _chipCategories.asMap().entries.toList();
    final visibleChips = state.hasChildren
        ? allChips
        : allChips
            .where((e) =>
                e.value != IdeaCategory.babysitterNight &&
                e.value != IdeaCategory.parentMode)
            .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.ideasTitle,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.ideasSubtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: s.ideasAll,
                            selected: _selectedCategory == null,
                            onTap: () =>
                                setState(() => _selectedCategory = null),
                          ),
                          const SizedBox(width: 8),
                          ...visibleChips.map((entry) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _FilterChip(
                                  label: chipLabels[entry.key],
                                  selected:
                                      _selectedCategory == entry.value,
                                  onTap: () => setState(() =>
                                      _selectedCategory =
                                          _selectedCategory == entry.value
                                              ? null
                                              : entry.value),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    s.ideasEmpty,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 15),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final idea = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DateIdeaCard(
                          idea: idea,
                          onFavorite: () => state.toggleFavorite(idea.id),
                          onSuggest: () => _showSuggested(context),
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSuggested(BuildContext context) {
    final s = context.read<LanguageProvider>().s;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.ideasSuggestionSent),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.textPrimary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentRose : AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.accentRose : AppTheme.divider,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppTheme.white
                : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
