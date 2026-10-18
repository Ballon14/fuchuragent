import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../customers/models/customer_model.dart';
import '../../invoices/models/invoice_model.dart';
import '../../payments/models/payment_model.dart';
import '../../expenses/models/expense_model.dart';
import '../models/financial_summary_model.dart';

class FinancialDataBundle {
  final TimeFilterHorizon horizon;
  final FinancialMetrics metrics;
  final List<CashflowLedgerItem> ledger;
  final List<MonthlyCashflowData> monthlyTrends;
  final List<ExpenseCategoryData> expenseCategories;
  final List<PaymentMethodDistribution> paymentMethods;
  final List<ReceivableAgingItem> agingReceivables;

  FinancialDataBundle({
    required this.horizon,
    required this.metrics,
    required this.ledger,
    required this.monthlyTrends,
    required this.expenseCategories,
    required this.paymentMethods,
    required this.agingReceivables,
  });
}

class FinanceRepository {
  final FirebaseFirestore? _firestore;

  // ignore: prefer_initializing_formals
  FinanceRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Stream full financial data bundle aggregating payments, expenses, invoices, and customers
  Stream<FinancialDataBundle> watchFinancialData({
    TimeFilterHorizon horizon = TimeFilterHorizon.thisMonth,
  }) {
    // Watch payments
    final paymentsStream = _db.collection('payments').snapshots();

    // Stream combine using nested mapping
    return paymentsStream.asyncMap((paymentsSnap) async {
      final expensesSnap = await _db.collection('expenses').get();
      final invoicesSnap = await _db.collection('invoices').get();
      final customersSnap = await _db.collection('customers').get();

      final allPayments = paymentsSnap.docs.map((d) => PaymentModel.fromFirestore(d)).toList();
      final allExpenses = expensesSnap.docs.map((d) => ExpenseModel.fromFirestore(d)).toList();
      final allInvoices = invoicesSnap.docs.map((d) => InvoiceModel.fromFirestore(d)).toList();
      final allCustomers = customersSnap.docs.map((d) => CustomerModel.fromFirestore(d)).toList();

      return processFinancialData(
        horizon: horizon,
        allPayments: allPayments,
        allExpenses: allExpenses,
        allInvoices: allInvoices,
        allCustomers: allCustomers,
      );
    });
  }

  /// Process raw data into comprehensive financial analytics bundle
  FinancialDataBundle processFinancialData({
    required TimeFilterHorizon horizon,
    required List<PaymentModel> allPayments,
    required List<ExpenseModel> allExpenses,
    required List<InvoiceModel> allInvoices,
    required List<CustomerModel> allCustomers,
  }) {
    final customerMap = <String, CustomerModel>{};
    for (final c in allCustomers) {
      customerMap[c.id] = c;
    }

    // 1. Filter by Horizon
    final validPayments = allPayments.where((p) {
      if (p.isReversed) return false;
      return horizon.matches(p.paymentDate);
    }).toList();

    final validExpenses = allExpenses.where((e) {
      return horizon.matches(e.expenseDate);
    }).toList();

    // 2. Compute Executive Metrics
    int totalInflow = 0;
    for (final p in validPayments) {
      totalInflow += p.amount;
    }

    int totalOutflow = 0;
    for (final e in validExpenses) {
      totalOutflow += e.amount;
    }

    final netProfit = totalInflow - totalOutflow;
    final profitMargin = totalInflow > 0 ? (netProfit / totalInflow) * 100 : 0.0;

    // Piutang (Open receivables)
    int outstandingReceivables = 0;
    int unpaidCount = 0;
    int totalInvoiced = 0;
    int totalCollected = 0;

    for (final inv in allInvoices) {
      if (inv.status == 'cancelled') continue;
      totalInvoiced += inv.total;
      totalCollected += inv.paidAmount;

      if (!inv.isPaid) {
        unpaidCount++;
        outstandingReceivables += inv.remainingBalance;
      }
    }

    final collectionRate = totalInvoiced > 0 ? (totalCollected / totalInvoiced) * 100 : 100.0;

    final metrics = FinancialMetrics(
      totalInflow: totalInflow,
      totalOutflow: totalOutflow,
      netProfit: netProfit,
      profitMargin: profitMargin,
      outstandingReceivables: outstandingReceivables,
      totalInvoicesCount: allInvoices.length,
      unpaidInvoicesCount: unpaidCount,
      collectionRate: collectionRate,
    );

    // 3. Unified Cashflow Ledger (Combined & Chronologically Sorted)
    final ledgerItems = <CashflowLedgerItem>[];

    for (final p in validPayments) {
      final cust = customerMap[p.customerId];
      ledgerItems.add(CashflowLedgerItem.fromPayment(p, customerName: cust?.name ?? ''));
    }

    for (final e in validExpenses) {
      ledgerItems.add(CashflowLedgerItem.fromExpense(e));
    }

    ledgerItems.sort((a, b) => b.date.compareTo(a.date));

    // 4. Monthly Cashflow Trends (Last 6 Months)
    final now = DateTime.now();
    final monthlyTrends = <MonthlyCashflowData>[];
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    for (int i = 5; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final year = targetDate.year;
      final month = targetDate.month;
      final label = '${monthNames[month - 1]} ${year.toString().substring(2)}';

      int mInflow = 0;
      for (final p in allPayments) {
        if (!p.isReversed && p.paymentDate != null) {
          if (p.paymentDate!.year == year && p.paymentDate!.month == month) {
            mInflow += p.amount;
          }
        }
      }

      int mOutflow = 0;
      for (final e in allExpenses) {
        if (e.expenseDate.year == year && e.expenseDate.month == month) {
          mOutflow += e.amount;
        }
      }

      monthlyTrends.add(MonthlyCashflowData(
        year: year,
        month: month,
        monthLabel: label,
        inflow: mInflow,
        outflow: mOutflow,
      ));
    }

    // 5. Expense Breakdown by Category
    final expenseCatMap = <String, List<ExpenseModel>>{};
    for (final e in validExpenses) {
      final cat = e.category.toUpperCase();
      expenseCatMap.putIfAbsent(cat, () => []).add(e);
    }

    final expenseCategories = <ExpenseCategoryData>[];
    expenseCatMap.forEach((catKey, items) {
      final catAmount = items.fold<int>(0, (acc, item) => acc + item.amount);
      final pct = totalOutflow > 0 ? (catAmount / totalOutflow) * 100 : 0.0;
      final sample = items.first;

      expenseCategories.add(ExpenseCategoryData(
        category: catKey,
        categoryLabel: sample.categoryLabel,
        amount: catAmount,
        percentage: pct,
        count: items.length,
        color: sample.categoryColor,
        icon: sample.categoryIcon,
      ));
    });
    expenseCategories.sort((a, b) => b.amount.compareTo(a.amount));

    // 6. Revenue by Payment Channel / Method
    final payMethodMap = <String, List<PaymentModel>>{};
    for (final p in validPayments) {
      final mName = p.paymentMethod.isNotEmpty ? p.paymentMethod : 'Transfer Bank';
      payMethodMap.putIfAbsent(mName, () => []).add(p);
    }

    final paymentMethods = <PaymentMethodDistribution>[];
    payMethodMap.forEach((name, items) {
      final amt = items.fold<int>(0, (acc, item) => acc + item.amount);
      final pct = totalInflow > 0 ? (amt / totalInflow) * 100 : 0.0;
      paymentMethods.add(PaymentMethodDistribution(
        methodName: name,
        totalAmount: amt,
        transactionCount: items.length,
        percentage: pct,
      ));
    });
    paymentMethods.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // 7. Aging Receivables (Unpaid Invoices sorted by urgency)
    final agingReceivables = <ReceivableAgingItem>[];
    for (final inv in allInvoices) {
      if (inv.isPaid || inv.status == 'cancelled') continue;
      final cust = customerMap[inv.customerId];
      final dueDate = inv.dueDate;
      final isOverdue = dueDate != null && now.isAfter(dueDate);
      final daysOverdue = dueDate != null ? now.difference(dueDate).inDays : 0;

      agingReceivables.add(ReceivableAgingItem(
        invoice: inv,
        customerName: cust?.name.isNotEmpty == true ? cust!.name : 'Pelanggan #${inv.customerId.substring(0, 6)}',
        customerPhone: cust?.phone ?? '',
        remainingAmount: inv.remainingBalance,
        daysOverdue: daysOverdue,
        isOverdue: isOverdue,
      ));
    }
    // Sort: overdue first (highest days overdue), then closest due date
    agingReceivables.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));

    return FinancialDataBundle(
      horizon: horizon,
      metrics: metrics,
      ledger: ledgerItems,
      monthlyTrends: monthlyTrends,
      expenseCategories: expenseCategories,
      paymentMethods: paymentMethods,
      agingReceivables: agingReceivables,
    );
  }

  /// Exports financial ledger and executive summary to CSV format
  String generateFinancialCsv(FinancialDataBundle bundle) {
    final rows = <List<dynamic>>[];

    // Metadata & Summary Section
    rows.add(['LAPORAN ARUS KAS & KEUANGAN FUCHURHOST SOLUTIONS']);
    rows.add(['Periode Analisis', bundle.horizon.label]);
    rows.add(['Tanggal Ekspor', AppConstants.formatDate(DateTime.now())]);
    rows.add([]);

    rows.add(['RINGKASAN EKSEKUTIF KEUANGAN']);
    rows.add(['Metrik', 'Nilai (IDR)', 'Keterangan']);
    rows.add(['Total Kas Masuk (Inflow)', bundle.metrics.totalInflow, AppConstants.formatRupiah(bundle.metrics.totalInflow)]);
    rows.add(['Total Kas Keluar (Outflow)', bundle.metrics.totalOutflow, AppConstants.formatRupiah(bundle.metrics.totalOutflow)]);
    rows.add(['Laba Bersih Operasional', bundle.metrics.netProfit, AppConstants.formatRupiah(bundle.metrics.netProfit)]);
    rows.add(['Margin Keuntungan', '${bundle.metrics.profitMargin.toStringAsFixed(1)}%', 'Profit Margin']);
    rows.add(['Total Piutang Belum Tertagih', bundle.metrics.outstandingReceivables, AppConstants.formatRupiah(bundle.metrics.outstandingReceivables)]);
    rows.add(['Tingkat Penagihan (Collection Rate)', '${bundle.metrics.collectionRate.toStringAsFixed(1)}%', 'Persentase Tagihan Terbayar']);
    rows.add([]);

    // Detailed Unified Ledger Table
    rows.add(['BUKU KAS & MUTASI TRANSAKSI TERPADU']);
    rows.add([
      'No',
      'Tanggal Transaksi',
      'Tipe Mutasi',
      'Judul / Deskripsi',
      'Kategori',
      'Pihak Terkait (Pelanggan / Vendor)',
      'Metode Pembayaran',
      'No Referensi',
      'Arus Kas Masuk (Rp)',
      'Arus Kas Keluar (Rp)',
      'Catatan',
    ]);

    for (int i = 0; i < bundle.ledger.length; i++) {
      final item = bundle.ledger[i];
      rows.add([
        i + 1,
        AppConstants.formatDate(item.date),
        item.type.label,
        item.title,
        item.categoryLabel,
        item.partyName,
        item.paymentMethod,
        item.referenceNumber,
        item.isInflow ? item.amount : 0,
        item.isOutflow ? item.amount : 0,
        item.notes,
      ]);
    }

    return csv.encode(rows);
  }
}

// Horizon State Notifier
class HorizonNotifier extends Notifier<TimeFilterHorizon> {
  @override
  TimeFilterHorizon build() => TimeFilterHorizon.thisMonth;

  void setHorizon(TimeFilterHorizon h) => state = h;
}

// Providers
final financeRepositoryProvider = Provider<FinanceRepository>((ref) => FinanceRepository());

final selectedHorizonProvider = NotifierProvider<HorizonNotifier, TimeFilterHorizon>(HorizonNotifier.new);

final financialDataStreamProvider = StreamProvider.autoDispose<FinancialDataBundle>((ref) {
  final horizon = ref.watch(selectedHorizonProvider);
  return ref.watch(financeRepositoryProvider).watchFinancialData(horizon: horizon);
});
