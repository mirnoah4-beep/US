import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/language_provider.dart';
import '../theme/app_theme.dart';

class _Option {
  final String id;
  final IconData icon;
  const _Option({required this.id, required this.icon});
}

const _options = [
  _Option(id: 'went_out',   icon: Icons.directions_walk_outlined),
  _Option(id: 'home_date',  icon: Icons.home_outlined),
  _Option(id: 'game',       icon: Icons.sports_esports_outlined),
  _Option(id: 'date_night', icon: Icons.favorite_border),
  _Option(id: 'phone_free', icon: Icons.chat_bubble_outline),
  _Option(id: 'custom',     icon: Icons.add_circle_outline),
];

class LogMomentSheet extends StatefulWidget {
  final String? preSelected;
  final Function(String momentId) onLog;

  const LogMomentSheet({
    super.key,
    this.preSelected,
    required this.onLog,
  });

  @override
  State<LogMomentSheet> createState() => _LogMomentSheetState();
}

class _LogMomentSheetState extends State<LogMomentSheet> {
  String? _selected;
  final _customController = TextEditingController();
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    if (widget.preSelected != null) {
      final match = _options.where((o) => o.id == widget.preSelected).firstOrNull;
      if (match != null) _selected = match.id;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _handleLog() {
    if (_selected == null) return;
    widget.onLog(_selected!);
    setState(() => _logged = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F4),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 32 + bottomInset),
      child: _logged ? _buildSuccess(s) : _buildPicker(s),
    );
  }

  Widget _buildSuccess(s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: AppTheme.accentGreenLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: AppTheme.accentGreen, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          s.logSuccess,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.logSuccessMsg,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
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
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFD3D1C7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          s.logTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.logSubtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        _buildGrid(s),
        if (_selected == 'custom') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customController,
            maxLines: 2,
            maxLength: 100,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            decoration: InputDecoration(
              hintText: s.logCustomHint,
              hintStyle: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D9D0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D9D0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.accentRose),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _selected != null ? _handleLog : null,
            style: FilledButton.styleFrom(
              backgroundColor: _selected != null
                  ? AppTheme.accentRose
                  : const Color(0xFFE0D9D0),
              foregroundColor: _selected != null
                  ? Colors.white
                  : const Color(0xFFB4B2A9),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(s.logButton),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              s.logCancel,
              style: const TextStyle(
                color: Color(0xFFB4B2A9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(s) {
    final rows = <Widget>[];
    for (int i = 0; i < _options.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      final right = i + 1 < _options.length ? _options[i + 1] : null;
      rows.add(Row(
        children: [
          Expanded(child: _chip(_options[i], s)),
          const SizedBox(width: 10),
          Expanded(child: right != null ? _chip(right, s) : const SizedBox()),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _chip(_Option opt, s) {
    final isSelected = _selected == opt.id;
    return GestureDetector(
      onTap: () => setState(() => _selected = opt.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAECE7) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentRose : const Color(0xFFE0D9D0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              opt.icon,
              color: isSelected ? AppTheme.accentRose : AppTheme.textSubtle,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.logOptionLabel(opt.id),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF4A1B0C)
                      : const Color(0xFF2C2420),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
