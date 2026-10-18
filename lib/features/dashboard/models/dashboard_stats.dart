import '../../customers/models/customer_model.dart';
import '../../services/models/service_model.dart';
import '../../payments/models/payment_model.dart';
import '../../audit/models/activity_log_model.dart';

class DashboardStats {
  final int totalCustomers;
  final int activeCustomers;
  final int totalServices;
  final int activeServices;
  final int expiringServicesCount;
  final int expiredServicesCount;
  final int unpaidInvoicesCount;
  final int overdueInvoicesCount;
  final int unpaidAmount;
  final int totalRevenue;
  final int totalExpenses;
  final List<PaymentModel> recentPayments;
  final List<CustomerModel> recentCustomers;
  final List<ActivityLogModel> recentActivities;
  final List<VpsServiceModel> followUpServices;

  DashboardStats({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.totalServices,
    required this.activeServices,
    required this.expiringServicesCount,
    required this.expiredServicesCount,
    required this.unpaidInvoicesCount,
    required this.overdueInvoicesCount,
    required this.unpaidAmount,
    required this.totalRevenue,
    this.totalExpenses = 0,
    required this.recentPayments,
    required this.recentCustomers,
    required this.recentActivities,
    required this.followUpServices,
  });

  int get netProfit => totalRevenue - totalExpenses;

  factory DashboardStats.empty() {
    return DashboardStats(
      totalCustomers: 0,
      activeCustomers: 0,
      totalServices: 0,
      activeServices: 0,
      expiringServicesCount: 0,
      expiredServicesCount: 0,
      unpaidInvoicesCount: 0,
      overdueInvoicesCount: 0,
      unpaidAmount: 0,
      totalRevenue: 0,
      totalExpenses: 0,
      recentPayments: [],
      recentCustomers: [],
      recentActivities: [],
      followUpServices: [],
    );
  }
}
