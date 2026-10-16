import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String display = label ?? status;

    final s = status.toLowerCase();

    if (s == 'active' || s == 'actice' || s == 'paid' || s == 'lunas') {
      bg = AppColors.success.withValues(alpha: 0.15);
      fg = AppColors.success;
      if (s == 'actice') display = 'Aktif';
      if (s == 'active') display = 'Aktif';
      if (s == 'paid' || s == 'lunas') display = 'Lunas';
    } else if (s == 'pending' || s == 'partial' || s == 'draft') {
      bg = AppColors.warning.withValues(alpha: 0.15);
      fg = AppColors.warning;
      if (s == 'partial') display = 'Sebagian';
      if (s == 'pending') display = 'Tertunda';
    } else if (s == 'expired' || s == 'deactive' || s == 'inactive' || s == 'overdue' || s == 'terlambat') {
      bg = AppColors.danger.withValues(alpha: 0.15);
      fg = AppColors.danger;
      if (s == 'deactive') display = 'Nonaktif';
      if (s == 'expired') display = 'Kedaluwarsa';
      if (s == 'overdue') display = 'Terlambat';
    } else if (s == 'cancelled' || s == 'dibatalkan' || s == 'archived') {
      bg = Colors.grey.withValues(alpha: 0.2);
      fg = Colors.grey.shade400;
      if (s == 'cancelled') display = 'Dibatalkan';
      if (s == 'archived') display = 'Diarsipkan';
    } else {
      bg = AppColors.cyan.withValues(alpha: 0.15);
      fg = AppColors.cyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        display.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
