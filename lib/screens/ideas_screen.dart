import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language_provider.dart';
import '../theme/app_theme.dart';

// ─── Color palettes ───────────────────────────────────────────────────────────

class _Palette {
  final Color bg;
  final Color border;
  final Color icon;
  final Color tagBg;
  final Color tagText;
  const _Palette(this.bg, this.border, this.icon, this.tagBg, this.tagText);
}

const _kPalettes = [
  _Palette(Color(0xFFFAECE7), Color(0xFFF5C4B3), Color(0xFF993C1D), Color(0xFFF5C4B3), Color(0xFF712B13)),
  _Palette(Color(0xFFEAF3DE), Color(0xFFC0DD97), Color(0xFF3B6D11), Color(0xFFC0DD97), Color(0xFF27500A)),
  _Palette(Color(0xFFFAEEDA), Color(0xFFFAC775), Color(0xFF854F0B), Color(0xFFFAC775), Color(0xFF633806)),
  _Palette(Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF0F6E56), Color(0xFF9FE1CB), Color(0xFF085041)),
  _Palette(Color(0xFFFBEAF0), Color(0xFFF4C0D1), Color(0xFF993556), Color(0xFFF4C0D1), Color(0xFF72243E)),
  _Palette(Color(0xFFEEEDFE), Color(0xFFCECBF6), Color(0xFF534AB7), Color(0xFFCECBF6), Color(0xFF3C3489)),
];

// ─── Idea model ───────────────────────────────────────────────────────────────

class _IdeaItem {
  final String id;
  final String titleEn, titleNo;
  final String durationEn, durationNo;
  final String categoryEn, categoryNo;
  final String descEn, descNo;
  final IconData icon;
  final String filter; // '10min' | 'athome' | 'out' | '1hour'
  final int colorIndex;

  const _IdeaItem({
    required this.id,
    required this.titleEn, required this.titleNo,
    required this.durationEn, required this.durationNo,
    required this.categoryEn, required this.categoryNo,
    required this.descEn, required this.descNo,
    required this.icon,
    required this.filter,
    required this.colorIndex,
  });

  String title(bool no) => no ? titleNo : titleEn;
  String duration(bool no) => no ? durationNo : durationEn;
  String category(bool no) => no ? categoryNo : categoryEn;
  String desc(bool no) => no ? descNo : descEn;
}

// TODO: connect to Firestore when backend ready
const List<_IdeaItem> _kIdeas = [
  _IdeaItem(
    id: 'question_cards',
    titleEn: 'Question cards on the couch',
    titleNo: 'Spørsmålskort i sofaen',
    durationEn: '10 min', durationNo: '10 min',
    categoryEn: '10 min', categoryNo: '10 min',
    descEn: 'Pick a deck of questions and take turns asking each other. No phones, no distractions.',
    descNo: 'Velg et kortstokk med spørsmål og still hverandre på omgang. Ingen telefoner, ingen avbrytelser.',
    icon: Icons.quiz_outlined,
    filter: '10min', colorIndex: 0,
  ),
  _IdeaItem(
    id: 'evening_walk',
    titleEn: 'Evening walk without phones',
    titleNo: 'Kveldstur uten telefoner',
    durationEn: '30 min', durationNo: '30 min',
    categoryEn: 'Out together', categoryNo: 'Ute sammen',
    descEn: 'Leave the phones at home. Walk your neighbourhood and just talk.',
    descNo: 'La telefonene hjemme. Gå i nabolaget og bare prat.',
    icon: Icons.directions_walk_outlined,
    filter: 'out', colorIndex: 1,
  ),
  _IdeaItem(
    id: 'cook_together',
    titleEn: 'Cook a new recipe together',
    titleNo: 'Lag en ny oppskrift sammen',
    durationEn: '45 min', durationNo: '45 min',
    categoryEn: 'At home', categoryNo: 'Hjemme',
    descEn: 'Choose a recipe neither of you has tried. Divide the prep and enjoy it together.',
    descNo: 'Velg en oppskrift ingen av dere har prøvd. Del forberedelsene og nyt det sammen.',
    icon: Icons.restaurant_outlined,
    filter: 'athome', colorIndex: 2,
  ),
  _IdeaItem(
    id: 'tea_night',
    titleEn: 'Tea + dessert night',
    titleNo: 'Te + dessertkveld',
    durationEn: '20 min', durationNo: '20 min',
    categoryEn: 'At home', categoryNo: 'Hjemme',
    descEn: 'Brew your favourite tea, grab something sweet and just be together on the couch.',
    descNo: 'Trekk favorittteen, ta noe søtt og bare vær sammen i sofaen.',
    icon: Icons.local_cafe_outlined,
    filter: 'athome', colorIndex: 3,
  ),
  _IdeaItem(
    id: 'mini_trip',
    titleEn: 'Plan a mini trip together',
    titleNo: 'Planlegg en minitur sammen',
    durationEn: '10 min', durationNo: '10 min',
    categoryEn: '10 min', categoryNo: '10 min',
    descEn: 'Spend 10 minutes browsing ideas for a weekend away — even if you do not book yet.',
    descNo: 'Bruk 10 minutter på å bla gjennom idéer for en helgetur — selv om dere ikke bestiller ennå.',
    icon: Icons.map_outlined,
    filter: '10min', colorIndex: 4,
  ),
  _IdeaItem(
    id: 'bowling',
    titleEn: 'Bowling or mini-golf',
    titleNo: 'Bowling eller minigolf',
    durationEn: '1 hour+', durationNo: '1 time+',
    categoryEn: '1 hour+', categoryNo: '1 time+',
    descEn: 'Pick something a little silly and competitive. Low pressure, high fun.',
    descNo: 'Velg noe litt tåpelig og konkurransepreget. Lavt press, høy moro.',
    icon: Icons.sports_outlined,
    filter: '1hour', colorIndex: 5,
  ),
  _IdeaItem(
    id: 'coffee_walk',
    titleEn: 'Morning coffee walk',
    titleNo: 'Morgentur med kaffe',
    durationEn: '30 min', durationNo: '30 min',
    categoryEn: 'Out together', categoryNo: 'Ute sammen',
    descEn: 'Start the day together with a walk and a takeaway coffee. Just the two of you.',
    descNo: 'Start dagen sammen med en tur og en takeaway-kaffe. Bare dere to.',
    icon: Icons.coffee_outlined,
    filter: 'out', colorIndex: 0,
  ),
  _IdeaItem(
    id: 'write_letters',
    titleEn: 'Write each other a letter',
    titleNo: 'Skriv hverandre et brev',
    durationEn: '10 min', durationNo: '10 min',
    categoryEn: '10 min', categoryNo: '10 min',
    descEn: 'Pen and paper. Write one thing you love about them right now and swap.',
    descNo: 'Penn og papir. Skriv én ting du elsker ved dem akkurat nå og bytt.',
    icon: Icons.edit_outlined,
    filter: '10min', colorIndex: 1,
  ),
  _IdeaItem(
    id: 'local_market',
    titleEn: 'Visit a local market',
    titleNo: 'Besøk et lokalt marked',
    durationEn: '1 hour+', durationNo: '1 time+',
    categoryEn: '1 hour+', categoryNo: '1 time+',
    descEn: 'Wander through a market together. Grab a snack and people-watch.',
    descNo: 'Vandre gjennom et marked sammen. Ta en snack og se på folk.',
    icon: Icons.store_outlined,
    filter: '1hour', colorIndex: 2,
  ),
  _IdeaItem(
    id: 'dance_kitchen',
    titleEn: 'Dance in the kitchen',
    titleNo: 'Dans på kjøkkenet',
    durationEn: '10 min', durationNo: '10 min',
    categoryEn: '10 min', categoryNo: '10 min',
    descEn: 'Put on a favourite song and just dance. It does not have to be good.',
    descNo: 'Sett på en favorittlåt og dans. Det trenger ikke å være bra.',
    icon: Icons.music_note_outlined,
    filter: '10min', colorIndex: 3,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class IdeasScreen extends StatefulWidget {
  const IdeasScreen({super.key});

  @override
  State<IdeasScreen> createState() => _IdeasScreenState();
}

class _IdeasScreenState extends State<IdeasScreen> {
  String _activeFilter = 'all';
  Set<String> _savedIds = {};
  static const _prefsKey = 'saved_idea_ids';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) setState(() => _savedIds = raw.toSet());
  }

  Future<void> _toggleSave(String id) async {
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _savedIds.toList());
  }

  List<_IdeaItem> get _filtered {
    if (_activeFilter == 'all') return _kIdeas;
    return _kIdeas.where((i) => i.filter == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final isNo = s.isNorwegian;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
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
                        color: Color(0xFF1A1A1A),
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.ideasSubtitle,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: s.ideasAll,
                            active: _activeFilter == 'all',
                            onTap: () => setState(() => _activeFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: s.ideasChip10min,
                            active: _activeFilter == '10min',
                            onTap: () => setState(() => _activeFilter = '10min'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: s.ideasFilterAtHome,
                            active: _activeFilter == 'athome',
                            onTap: () => setState(() => _activeFilter = 'athome'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: s.ideasFilterOut,
                            active: _activeFilter == 'out',
                            onTap: () => setState(() => _activeFilter = 'out'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: s.ideasFilter1Hour,
                            active: _activeFilter == '1hour',
                            onTap: () => setState(() => _activeFilter = '1hour'),
                          ),
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
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 15),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final idea = filtered[index];
                      final palette = _kPalettes[idea.colorIndex % _kPalettes.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _IdeaCard(
                          key: ValueKey(idea.id),
                          idea: idea,
                          palette: palette,
                          isSaved: _savedIds.contains(idea.id),
                          isNorwegian: isNo,
                          onHeartTap: () => _toggleSave(idea.id),
                          onTap: () => _openDetail(context, idea, palette),
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

  void _openDetail(BuildContext context, _IdeaItem idea, _Palette palette) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IdeaDetailSheet(
        idea: idea,
        palette: palette,
        isSaved: _savedIds.contains(idea.id),
        onSave: () {
          Navigator.pop(ctx);
          _toggleSave(idea.id);
        },
        onSend: () {
          Navigator.pop(ctx);
          if (!mounted) return;
          final s = context.read<LanguageProvider>().s;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.ideasSuggestionSent),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        },
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _IdeaCard extends StatefulWidget {
  final _IdeaItem idea;
  final _Palette palette;
  final bool isSaved;
  final bool isNorwegian;
  final VoidCallback onHeartTap;
  final VoidCallback onTap;

  const _IdeaCard({
    super.key,
    required this.idea,
    required this.palette,
    required this.isSaved,
    required this.isNorwegian,
    required this.onHeartTap,
    required this.onTap,
  });

  @override
  State<_IdeaCard> createState() => _IdeaCardState();
}

class _IdeaCardState extends State<_IdeaCard> with SingleTickerProviderStateMixin {
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 2,
      ),
    ]).animate(_heartCtrl);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final isNo = widget.isNorwegian;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(widget.idea.icon, size: 22, color: p.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.idea.title(isNo),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.tagBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.idea.duration(isNo),
                      style: TextStyle(
                        color: p.tagText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _heartCtrl,
              builder: (context, _) => GestureDetector(
                onTap: () {
                  _heartCtrl.forward(from: 0);
                  widget.onHeartTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Transform.scale(
                    scale: _heartScale.value,
                    child: Icon(
                      widget.isSaved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: widget.isSaved
                          ? const Color(0xFFC1544A)
                          : p.border,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail sheet ─────────────────────────────────────────────────────────────

class _IdeaDetailSheet extends StatelessWidget {
  final _IdeaItem idea;
  final _Palette palette;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onSend;

  const _IdeaDetailSheet({
    required this.idea,
    required this.palette,
    required this.isSaved,
    required this.onSave,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final isNo = s.isNorwegian;
    final p = palette;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.tagBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              idea.category(isNo),
              style: TextStyle(
                color: p.tagText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            idea.title(isNo),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${idea.duration(isNo)} · ${idea.category(isNo)}',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(14),
            child: Text(
              idea.desc(isNo),
              style: const TextStyle(
                color: Color(0xFF2C2420),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSend,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC1544A),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(s.homeIdeaSendToPartner),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onSave,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFC1544A), width: 1.5),
                foregroundColor: const Color(0xFFC1544A),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(s.ideasSaveLater),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                s.ideasDismiss,
                style: const TextStyle(
                  color: Color(0xFFB4B2A9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFC1544A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFFC1544A) : const Color(0xFFE0D9D0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF555555),
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
