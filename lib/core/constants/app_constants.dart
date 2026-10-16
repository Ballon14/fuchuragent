import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppConstants {
  static const String appName = 'Fuchur Agent';
  static const String companyName = 'FuchurHost Solutions';
  static const String logoAsset = 'assets/images/logo.png';
  static const String currencyCode = 'IDR';
  static const String timezone = 'Asia/Jakarta';
  static const String superAdminEmail = 'iqbal140605@gmail.com';

  // Currency Formatter: Rp 135.000
  static String formatRupiah(int amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  // Parse Currency String: "Rp135,000.00" -> 135000
  static int parseRupiah(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.isEmpty) return 0;
    // Handle .00 if present
    if (input.contains('.00') && cleaned.endsWith('00')) {
      final withoutCents = cleaned.substring(0, cleaned.length - 2);
      return int.tryParse(withoutCents) ?? 0;
    }
    return int.tryParse(cleaned) ?? 0;
  }

  // Date Formatter: 18 Juli 2026
  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }

  // Short Date Formatter: 18/07/2026
  static String formatShortDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Date & Time Formatter
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dateTime);
  }

  // Parse US / Spreadsheet format: M/D/YYYY (e.g. 7/18/2026 or 7/4/2026)
  static DateTime? parseSpreadsheetDate(String input) {
    if (input.trim().isEmpty) return null;
    try {
      final parts = input.trim().split('/');
      if (parts.length == 3) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime.tryParse(input.trim());
  }
}

class AppColors {
  // Dark Palette (Primary)
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B);    // Slate 800
  static const Color surfaceLightDark = Color(0xFF334155); // Slate 700
  static const Color borderDark = Color(0xFF334155);

  // Light Palette (Alternative)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Brand Accents
  static const Color cyan = Color(0xFF06B6D4);        // Cyan 500
  static const Color electricBlue = Color(0xFF0EA5E9); // Sky 500
  static const Color indigoAccent = Color(0xFF6366F1); // Indigo 500

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color danger = Color(0xFFEF4444);  // Red 500
  static const Color info = Color(0xFF3B82F6);    // Blue 500
}
