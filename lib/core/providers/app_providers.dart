import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/customers/repositories/customer_repository.dart';
import '../../features/packages/repositories/package_repository.dart';
import '../../features/services/repositories/service_repository.dart';
import '../../features/invoices/repositories/invoice_repository.dart';
import '../../features/payments/repositories/payment_repository.dart';
import '../../features/renewals/repositories/renewal_repository.dart';
import '../../features/audit/repositories/audit_repository.dart';
import '../../features/notifications/repositories/notification_repository.dart';
import '../../features/imports/repositories/import_repository.dart';
import '../../features/dashboard/repositories/dashboard_repository.dart';
import '../../features/dashboard/models/dashboard_stats.dart';
import '../../features/expenses/repositories/expense_repository.dart';
import '../../features/settings/models/system_settings_model.dart';
import '../../features/settings/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
export '../../features/finance/repositories/finance_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const String _themeKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs != null) {
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme == 'light') {
        return ThemeMode.light;
      } else if (savedTheme == 'system') {
        return ThemeMode.system;
      } else if (savedTheme == 'dark') {
        return ThemeMode.dark;
      }
    } else {
      _loadSavedThemeAsync();
    }
    return ThemeMode.dark;
  }

  Future<void> _loadSavedThemeAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme == 'light' && state != ThemeMode.light) {
        state = ThemeMode.light;
      } else if (savedTheme == 'system' && state != ThemeMode.system) {
        state = ThemeMode.system;
      } else if (savedTheme == 'dark' && state != ThemeMode.dark) {
        state = ThemeMode.dark;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(newMode);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = ref.read(sharedPreferencesProvider) ?? await SharedPreferences.getInstance();
      String value = 'dark';
      if (mode == ThemeMode.light) {
        value = 'light';
      } else if (mode == ThemeMode.system) {
        value = 'system';
      }
      await prefs.setString(_themeKey, value);
    } catch (e) {
      debugPrint('Failed to persist themeMode: $e');
    }
  }
}

// Theme Mode Provider (Dark by default, persisted in local storage)
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Auth Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(authRepositoryProvider).watchCurrentUserProfile();
});

// Domain Repositories
final customerRepositoryProvider = Provider<CustomerRepository>((ref) => CustomerRepository());
final packageRepositoryProvider = Provider<PackageRepository>((ref) => PackageRepository());
final serviceRepositoryProvider = Provider<ServiceRepository>((ref) => ServiceRepository());
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) => InvoiceRepository());
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => PaymentRepository());
final renewalRepositoryProvider = Provider<RenewalRepository>((ref) => RenewalRepository());
final auditRepositoryProvider = Provider<AuditRepository>((ref) => AuditRepository());
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => NotificationRepository());
final importRepositoryProvider = Provider<ImportRepository>((ref) => ImportRepository());
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) => ExpenseRepository());
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

// System Settings Provider (real-time stream)
final systemSettingsProvider = StreamProvider<SystemSettingsModel>((ref) {
  return ref.watch(settingsRepositoryProvider).watchSettings();
});

// Dashboard Stats Provider (auto-refreshable)
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  return await ref.watch(dashboardRepositoryProvider).getDashboardStats();
});


