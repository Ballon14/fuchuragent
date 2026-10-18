import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../invoices/models/invoice_model.dart';
import '../../payments/models/payment_model.dart';
import '../../expenses/models/expense_model.dart';

/// Filter rentang waktu analisis keuangan
enum TimeFilterHorizon {
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  allTime;

  String get label {
    switch (this) {
      case TimeFilterHorizon.thisMonth:
        return 'Bulan Ini';
      case TimeFilterHorizon.lastMonth:
        return 'Bulan Lalu';
      case TimeFilterHorizon.last3Months:
        return '3 Bulan';
      case TimeFilterHorizon.thisYear:
        return 'Tahun Ini';
      case TimeFilterHorizon.allTime:
        return 'Semua Waktu';
    }
  }

  bool matches(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();

    switch (this) {
      case TimeFilterHorizon.thisMonth:
        return date.year == now.year && date.month == now.month;

      case TimeFilterHorizon.lastMonth:
        final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        return date.year == lastMonthYear && date.month == lastMonth;

      case TimeFilterHorizon.last3Months:
        final threeMonthsAgo = DateTime(now.year, now.month - 2, 1);
        final endOfCurrentMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return date.isAfter(threeMonthsAgo.subtract(const Duration(seconds: 1))) &&
            date.isBefore(endOfCurrentMonth.add(const Duration(seconds: 1)));

      case TimeFilterHorizon.thisYear:
        return date.year == now.year;

      case TimeFilterHorizon.allTime:
        return true;
    }
  }
}

/// Tipe mutasi kas
enum CashflowType {
  inflow, // Kas Masuk (Pembayaran Tagihan)
  outflow; // Kas Keluar (Pengeluaran Operasional)

  String get label => this == CashflowType.inflow ? 'Kas Masuk' : 'Kas Keluar';
}

/// Satu baris catatan transaksi di Buku Kas & Mutasi Terpadu
class CashflowLedgerItem {
  final String id;
  final CashflowType type;
  final DateTime date;
  final int amount;
  final String title;
  final String category;
  final String categoryLabel;
  final String paymentMethod;
  final String referenceNumber;
  final String partyName; // Nama Pelanggan atau Penerima Biaya
  final String notes;
  final String referenceId; // invoiceId atau expenseId
  final Color categoryColor;
  final IconData categoryIcon;

  CashflowLedgerItem({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.title,
    required this.category,
    required this.categoryLabel,
    required this.paymentMethod,
    this.referenceNumber = '',
    this.partyName = '',
    this.notes = '',
    this.referenceId = '',
    required this.categoryColor,
    required this.categoryIcon,
  });

  bool get isInflow => type == CashflowType.inflow;
  bool get isOutflow => type == CashflowType.outflow;

  factory CashflowLedgerItem.fromPayment(PaymentModel payment, {String customerName = ''}) {
    return CashflowLedgerItem(
      id: 'PAY-${payment.id}',
      type: CashflowType.inflow,
      date: payment.paymentDate ?? DateTime.now(),
      amount: payment.amount,
      title: 'Pelunasan Tagihan #${payment.invoiceId.length > 8 ? payment.invoiceId.substring(0, 8) : payment.invoiceId}',
      category: 'INVOICE_PAYMENT',
      categoryLabel: 'Pendapatan Invoice',
      paymentMethod: payment.paymentMethod.isNotEmpty ? payment.paymentMethod : 'Transfer Bank',
      referenceNumber: payment.referenceNumber,
      partyName: customerName.isNotEmpty ? customerName : 'Pelanggan',
      notes: payment.notes,
      referenceId: payment.invoiceId,
      categoryColor: const Color(0xFF10B981), // Emerald
      categoryIcon: Icons.arrow_downward_rounded,
    );
  }

  factory CashflowLedgerItem.fromExpense(ExpenseModel expense) {
    return CashflowLedgerItem(
      id: 'EXP-${expense.id}',
      type: CashflowType.outflow,
      date: expense.expenseDate,
      amount: expense.amount,
      title: expense.title,
      category: expense.category,
      categoryLabel: expense.categoryLabel,
      paymentMethod: expense.paymentMethod.isNotEmpty ? expense.paymentMethod : 'Transfer Bank',
      referenceNumber: expense.expenseNumber,
      partyName: expense.recipient.isNotEmpty ? expense.recipient : 'Vendor / Pihak Ketiga',
      notes: expense.notes,
      referenceId: expense.id,
      categoryColor: expense.categoryColor,
      categoryIcon: expense.categoryIcon,
    );
  }
}

/// Data ringkasan per bulan untuk grafik arus kas
class MonthlyCashflowData {
  final int year;
  final int month;
  final String monthLabel;
  final int inflow;
  final int outflow;

  MonthlyCashflowData({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.inflow,
    required this.outflow,
  });

  int get net => inflow - outflow;
  double get profitMargin => inflow > 0 ? (net / inflow) * 100 : 0.0;
}

/// Data distribusi kategori pengeluaran untuk donut chart
class ExpenseCategoryData {
  final String category;
  final String categoryLabel;
  final int amount;
  final double percentage;
  final int count;
  final Color color;
  final IconData icon;

  ExpenseCategoryData({
    required this.category,
    required this.categoryLabel,
    required this.amount,
    required this.percentage,
    required this.count,
    required this.color,
    required this.icon,
  });
}

/// Distribusi penerimaan pembayaran per metode pembayaran
class PaymentMethodDistribution {
  final String methodName;
  final int totalAmount;
  final int transactionCount;
  final double percentage;

  PaymentMethodDistribution({
    required this.methodName,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });
}

/// Data piutang belum tertagih (Aging Receivables)
class ReceivableAgingItem {
  final InvoiceModel invoice;
  final String customerName;
  final String customerPhone;
  final int remainingAmount;
  final int daysOverdue;
  final bool isOverdue;

  ReceivableAgingItem({
    required this.invoice,
    required this.customerName,
    required this.customerPhone,
    required this.remainingAmount,
    required this.daysOverdue,
    required this.isOverdue,
  });

  String get dueLabel {
    if (invoice.dueDate == null) return 'Tanpa Jatuh Tempo';
    final dateStr = AppConstants.formatDate(invoice.dueDate);
    if (isOverdue) {
      return 'Terlambat $daysOverdue hari (Jatuh tempo: $dateStr)';
    } else if (daysOverdue == 0) {
      return 'Jatuh tempo hari ini ($dateStr)';
    } else {
      return 'Jatuh tempo dlm ${-daysOverdue} hari ($dateStr)';
    }
  }
}

/// Metrik ringkasan eksekutif keuangan
class FinancialMetrics {
  final int totalInflow;
  final int totalOutflow;
  final int netProfit;
  final double profitMargin;
  final int outstandingReceivables;
  final int totalInvoicesCount;
  final int unpaidInvoicesCount;
  final double collectionRate;

  const FinancialMetrics({
    this.totalInflow = 0,
    this.totalOutflow = 0,
    this.netProfit = 0,
    this.profitMargin = 0.0,
    this.outstandingReceivables = 0,
    this.totalInvoicesCount = 0,
    this.unpaidInvoicesCount = 0,
    this.collectionRate = 0.0,
  });
}
