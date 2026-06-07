import 'package:flutter/material.dart';

import '../l10n/strings.dart';

class CalendarCard extends StatelessWidget {
  final DateTime displayMonth;
  final DateTime selectedDate;
  final Set<DateTime> eventDates;
  final AppStrings s;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  const CalendarCard({
    super.key,
    required this.displayMonth,
    required this.selectedDate,
    required this.eventDates,
    required this.s,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
    final offset = displayMonth.weekday - 1; // Mon=0 … Sun=6

    final cells = <Widget>[
      for (int i = 0; i < offset; i++) const SizedBox(),
      for (int day = 1; day <= daysInMonth; day++)
        _buildDayCell(
          day: day,
          date: DateTime(displayMonth.year, displayMonth.month, day),
          today: today,
        ),
    ];

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      if (i > 0) rows.add(const SizedBox(height: 4));
      rows.add(Row(
        children: [
          for (final cell in cells.sublist(i, i + 7)) Expanded(child: cell),
        ],
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D9D0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(icon: Icons.chevron_left, onTap: onPrevMonth),
              Text(
                s.planMonthYear(displayMonth),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A)),
              ),
              _NavButton(icon: Icons.chevron_right, onTap: onNextMonth),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: s.remindersDayAbbreviations
                .map((label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFB4B2A9)),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildDayCell(
      {required int day, required DateTime date, required DateTime today}) {
    final isPast = date.isBefore(today);
    final isToday = date == today;
    final isSelected = date == selectedDate;
    final hasEvent = eventDates.contains(date);

    Color textColor;
    Color? bgColor;
    FontWeight fw = FontWeight.w400;

    if (isSelected) {
      textColor = Colors.white;
      bgColor = const Color(0xFF8B2E42);
      fw = FontWeight.w500;
    } else if (isToday) {
      textColor = const Color(0xFF8B2E42);
      bgColor = const Color(0xFFFAECE7);
      fw = FontWeight.w500;
    } else if (isPast) {
      textColor = const Color(0xFFD3D1C7);
    } else {
      textColor = const Color(0xFF1A1A1A);
    }

    return GestureDetector(
      onTap: isPast ? null : () => onSelectDate(date),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: bgColor != null
                ? BoxDecoration(color: bgColor, shape: BoxShape.circle)
                : null,
            alignment: Alignment.center,
            child: Text('$day',
                style: TextStyle(
                    fontSize: 13, color: textColor, fontWeight: fw)),
          ),
          if (hasEvent)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(
                  color: Color(0xFF8B2E42), shape: BoxShape.circle),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: const Color(0xFF2C2420)),
      ),
    );
  }
}
