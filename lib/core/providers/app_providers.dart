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

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

// Theme Mode Provider (Dark by default)
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

// Dashboard Stats Provider (auto-refreshable)
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  return await ref.watch(dashboardRepositoryProvider).getDashboardStats();
});
