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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = status.toLowerCase();

    if (s == 'active' || s == 'actice' || s == 'paid' || s == 'lunas') {
      bg = (isDark ? AppColors.success : const Color(0xFF10B981)).withValues(alpha: isDark ? 0.15 : 0.12);
      fg = isDark ? AppColors.success : const Color(0xFF047857);
      if (s == 'actice') display = 'Aktif';
      if (s == 'active') display = 'Aktif';
      if (s == 'paid' || s == 'lunas') display = 'Lunas';
    } else if (s == 'pending' || s == 'partial' || s == 'draft') {
      bg = (isDark ? AppColors.warning : const Color(0xFFF59E0B)).withValues(alpha: isDark ? 0.15 : 0.12);
      fg = isDark ? AppColors.warning : const Color(0xFFB45309);
      if (s == 'partial') display = 'Sebagian';
      if (s == 'pending') display = 'Tertunda';
    } else if (s == 'expired' || s == 'deactive' || s == 'inactive' || s == 'overdue' || s == 'terlambat') {
      bg = (isDark ? AppColors.danger : const Color(0xFFEF4444)).withValues(alpha: isDark ? 0.15 : 0.12);
      fg = isDark ? AppColors.danger : const Color(0xFFB91C1C);
      if (s == 'deactive' || s == 'inactive' || s == 'expired') display = 'Nonaktif';
      if (s == 'overdue' || s == 'terlambat') display = 'Terlambat';
    } else if (s == 'cancelled' || s == 'dibatalkan' || s == 'archived') {
      bg = (isDark ? Colors.grey : const Color(0xFF94A3B8)).withValues(alpha: isDark ? 0.2 : 0.15);
      fg = isDark ? Colors.grey.shade400 : const Color(0xFF475569);
      if (s == 'cancelled') display = 'Dibatalkan';
      if (s == 'archived') display = 'Diarsipkan';
    } else {
      bg = (isDark ? AppColors.cyan : const Color(0xFF0284C7)).withValues(alpha: isDark ? 0.15 : 0.12);
      fg = isDark ? AppColors.cyan : const Color(0xFF0369A1);
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
