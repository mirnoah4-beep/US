import 'package:flutter/material.dart';
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

class _LogMomentSheetState extends State<LogMomentSheet> {
  String? _selected;
  bool _logged = false;

  List<LogMomentOption> get _visibleOptions {
    if (widget.hasChildren) return _options;
    return _options.where((o) => !o.parentModeOnly).toList();
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: _logged ? _buildSuccess() : _buildPicker(),
    );
  }

  Widget _buildSuccess() {
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
        const Text(
          'Logged!',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nice. Small moments keep love strong.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPicker() {
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
        const Text(
          'Log a moment',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'What did you do together?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        ..._visibleOptions.map((opt) => _buildOption(opt)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selected != null ? _handleLog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selected != null ? AppTheme.accentRose : AppTheme.divider,
              foregroundColor: _selected != null ? AppTheme.white : AppTheme.textMuted,
            ),
            child: const Text('Log moment'),
          ),
        ),
      ],
    );
  }

  Widget _buildOption(LogMomentOption opt) {
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
              opt.label,
              style: TextStyle(
                color: isSelected ? AppTheme.accentRose : AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.accentRose, size: 20),
          ],
        ),
      ),
    );
  }
}
