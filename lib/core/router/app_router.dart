import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/widgets/app_shell.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/dashboard/views/dashboard_screen.dart';
import '../../features/customers/views/customer_list_screen.dart';
import '../../features/customers/views/customer_detail_screen.dart';
import '../../features/services/views/service_list_screen.dart';
import '../../features/services/views/service_detail_screen.dart';
import '../../features/packages/views/package_list_screen.dart';
import '../../features/invoices/views/invoice_list_screen.dart';
import '../../features/invoices/views/invoice_detail_screen.dart';
import '../../features/payments/views/payment_list_screen.dart';
import '../../features/renewals/views/renewal_list_screen.dart';
import '../../features/reports/views/report_screen.dart';
import '../../features/notifications/views/notification_list_screen.dart';
import '../../features/settings/views/users_management_screen.dart';
import '../../features/settings/views/settings_screen.dart';
import '../../features/audit/views/audit_log_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggingIn = state.matchedLocation == '/login';

    if (user == null && !isLoggingIn) {
      return '/login';
    }

    if (user != null && isLoggingIn) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AppShell(
          currentRoute: state.matchedLocation,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomerListScreen(),
        ),
        GoRoute(
          path: '/customers/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return CustomerDetailScreen(customerId: id);
          },
        ),
        GoRoute(
          path: '/services',
          builder: (context, state) => const ServiceListScreen(),
        ),
        GoRoute(
          path: '/services/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return ServiceDetailScreen(serviceId: id);
          },
        ),
        GoRoute(
          path: '/packages',
          builder: (context, state) => const PackageListScreen(),
        ),
        GoRoute(
          path: '/invoices',
          builder: (context, state) => const InvoiceListScreen(),
        ),
        GoRoute(
          path: '/invoices/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return InvoiceDetailScreen(invoiceId: id);
          },
        ),
        GoRoute(
          path: '/payments',
          builder: (context, state) => const PaymentListScreen(),
        ),
        GoRoute(
          path: '/renewals',
          builder: (context, state) => const RenewalListScreen(),
        ),
        GoRoute(
          path: '/imports',
          redirect: (context, state) => '/customers',
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationListScreen(),
        ),
        GoRoute(
          path: '/users',
          builder: (context, state) => const UsersManagementScreen(),
        ),
        GoRoute(
          path: '/audit',
          builder: (context, state) => const AuditLogScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
