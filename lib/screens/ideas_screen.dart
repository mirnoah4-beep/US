import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/date_idea.dart';
import '../theme/app_theme.dart';
import '../widgets/date_idea_card.dart';

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  IdeaCategory? _selectedCategory;

  static const _chips = [
    (label: '10 min', category: IdeaCategory.tenMin),
    (label: '30 min at home', category: IdeaCategory.thirtyAtHome),
    (label: '1 hour out', category: IdeaCategory.oneHourOut),
    (label: 'Babysitter night', category: IdeaCategory.babysitterNight),
    (label: 'Parent mode', category: IdeaCategory.parentMode),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allIdeas = state.visibleIdeas;
    final filtered = _selectedCategory == null
        ? allIdeas
        : allIdeas.where((i) => i.category == _selectedCategory).toList();

    final chips = state.hasChildren
        ? _chips
        : _chips.where((c) => c.category != IdeaCategory.babysitterNight && c.category != IdeaCategory.parentMode).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date ideas',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Small ideas, big connection.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _selectedCategory == null,
                            onTap: () => setState(() => _selectedCategory = null),
                          ),
                          const SizedBox(width: 8),
                          ...chips.map((c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _FilterChip(
                                  label: c.label,
                                  selected: _selectedCategory == c.category,
                                  onTap: () => setState(() => _selectedCategory =
                                      _selectedCategory == c.category ? null : c.category),
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
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No ideas in this category.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final idea = filtered[index];
                      return DateIdeaCard(
                        idea: idea,
                        onFavorite: () => state.toggleFavorite(idea.id),
                        onSuggest: () => _showSuggested(context),
                      );
                    },
                    childCount: filtered.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSuggested(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Suggestion sent to your partner!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            color: selected ? AppTheme.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
