import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dashboard_stats.dart';
import '../../customers/models/customer_model.dart';
import '../../services/models/service_model.dart';
import '../../payments/models/payment_model.dart';
import '../../audit/models/activity_log_model.dart';

class DashboardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DashboardStats> getDashboardStats() async {
    // 1. Services (Dibutuhkan untuk parameter status pelanggan aktif / nonaktif)
    final servicesSnap = await _firestore.collection('vps_services').get();
    final allServices = servicesSnap.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();
    final totalServices = allServices.length;
    final activeServices = allServices.where((s) => s.isActive).length;

    final now = DateTime.now();

    // ID Pelanggan Aktif: memiliki minimal 1 layanan VPS berstatus aktif yang belum kedaluwarsa
    final activeCustomerIds = allServices
        .where((s) => s.isActive && s.endDate != null && s.endDate!.isAfter(now))
        .map((s) => s.customerId)
        .toSet();

    // 2. Customers
    final customersSnap = await _firestore.collection('customers').orderBy('createdAt', descending: true).get();
    final allCustomers = customersSnap.docs.map((d) => CustomerModel.fromFirestore(d)).toList();
    final totalCustomers = allCustomers.length;
    final activeCustomers = allCustomers.where((c) => !c.isArchived && activeCustomerIds.contains(c.id)).length;
    final recentCustomers = allCustomers.take(5).map((c) {
      final dynamicStatus = c.isArchived
          ? 'archived'
          : (activeCustomerIds.contains(c.id) ? 'active' : 'inactive');
      return c.copyWith(status: dynamicStatus);
    }).toList();
    final sevenDaysLater = now.add(const Duration(days: 7));

    final expiringServices = allServices.where((s) {
      if (!s.isActive || s.endDate == null) return false;
      return s.endDate!.isAfter(now) && s.endDate!.isBefore(sevenDaysLater);
    }).toList();

    final expiredServices = allServices.where((s) {
      if (s.endDate == null) return false;
      return s.endDate!.isBefore(now);
    }).toList();

    final followUpServices = [...expiringServices, ...expiredServices].take(6).toList();

    // 3. Invoices
    final invoicesSnap = await _firestore.collection('invoices').get();
    int unpaidCount = 0;
    int overdueCount = 0;
    int unpaidAmount = 0;

    for (final doc in invoicesSnap.docs) {
      final data = doc.data();
      final status = (data['status'] as String? ?? 'unpaid').toLowerCase();
      final total = (data['total'] as num?)?.toInt() ?? 0;
      final paid = (data['paidAmount'] as num?)?.toInt() ?? 0;
      final dueTimestamp = data['dueDate'] as Timestamp?;
      final dueDate = dueTimestamp?.toDate();

      if (status != 'paid' && status != 'cancelled') {
        unpaidCount++;
        unpaidAmount += (total - paid).clamp(0, total);
        if (dueDate != null && dueDate.isBefore(now)) {
          overdueCount++;
        }
      }
    }

    // 4. Payments (Actual Received Revenue)
    final paymentsSnap = await _firestore.collection('payments').orderBy('paymentDate', descending: true).get();
    final allPayments = paymentsSnap.docs.map((d) => PaymentModel.fromFirestore(d)).toList();

    int totalRevenue = 0;
    for (final p in allPayments) {
      if (!p.isReversed) {
        totalRevenue += p.amount;
      }
    }
    final recentPayments = allPayments.take(5).toList();

    // 5. Expenses (Total Pengeluaran Operasional)
    final expensesSnap = await _firestore.collection('expenses').get();
    int totalExpenses = 0;
    for (final doc in expensesSnap.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      totalExpenses += amount;
    }

    // 6. Activity Logs
    final logsSnap = await _firestore.collection('activity_logs').orderBy('timestamp', descending: true).limit(6).get();
    final recentActivities = logsSnap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();

    return DashboardStats(
      totalCustomers: totalCustomers,
      activeCustomers: activeCustomers,
      totalServices: totalServices,
      activeServices: activeServices,
      expiringServicesCount: expiringServices.length,
      expiredServicesCount: expiredServices.length,
      unpaidInvoicesCount: unpaidCount,
      overdueInvoicesCount: overdueCount,
      unpaidAmount: unpaidAmount,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      recentPayments: recentPayments,
      recentCustomers: recentCustomers,
      recentActivities: recentActivities,
      followUpServices: followUpServices,
    );
  }
}
