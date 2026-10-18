import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/finance/models/financial_summary_model.dart';
import 'package:fuchuragent/features/finance/repositories/finance_repository.dart';
import 'package:fuchuragent/features/payments/models/payment_model.dart';
import 'package:fuchuragent/features/expenses/models/expense_model.dart';
import 'package:fuchuragent/features/invoices/models/invoice_model.dart';
import 'package:fuchuragent/features/customers/models/customer_model.dart';

void main() {
  group('TimeFilterHorizon Tests', () {
    test('TimeFilterHorizon.allTime matches any date', () {
      final pastDate = DateTime(2020, 1, 1);
      final futureDate = DateTime(2030, 1, 1);

      expect(TimeFilterHorizon.allTime.matches(pastDate), isTrue);
      expect(TimeFilterHorizon.allTime.matches(futureDate), isTrue);
      expect(TimeFilterHorizon.allTime.matches(null), isFalse);
    });

    test('TimeFilterHorizon.thisMonth matches current month dates only', () {
      final now = DateTime.now();
      final sameMonth = DateTime(now.year, now.month, 10);
      final prevMonth = DateTime(now.year, now.month == 1 ? 12 : now.month - 1, 10);

      expect(TimeFilterHorizon.thisMonth.matches(sameMonth), isTrue);
      if (now.month > 1) {
        expect(TimeFilterHorizon.thisMonth.matches(prevMonth), isFalse);
      }
    });

    test('TimeFilterHorizon.thisYear matches current year dates', () {
      final now = DateTime.now();
      final thisYearDate = DateTime(now.year, 1, 15);
      final lastYearDate = DateTime(now.year - 1, 12, 31);

      expect(TimeFilterHorizon.thisYear.matches(thisYearDate), isTrue);
      expect(TimeFilterHorizon.thisYear.matches(lastYearDate), isFalse);
    });
  });

  group('Finance Processing & Metrics Calculation Tests', () {
    final now = DateTime.now();
    final repo = FinanceRepository();

    final testCustomers = [
      CustomerModel(id: 'c1', name: 'PT Digital Solusindo', phone: '08123456789', email: 'pt@ds.com'),
      CustomerModel(id: 'c2', name: 'Budi Santoso', phone: '08987654321', email: 'budi@mail.com'),
    ];

    final testPayments = [
      PaymentModel(
        id: 'p1',
        invoiceId: 'inv-001',
        customerId: 'c1',
        amount: 2500000,
        paymentDate: now,
        paymentMethod: 'Bank Mandiri',
        referenceNumber: 'TRX-101',
        isReversed: false,
      ),
      PaymentModel(
        id: 'p2',
        invoiceId: 'inv-002',
        customerId: 'c2',
        amount: 1500000,
        paymentDate: now,
        paymentMethod: 'QRIS',
        referenceNumber: 'TRX-102',
        isReversed: false,
      ),
      PaymentModel(
        id: 'p3_reversed',
        invoiceId: 'inv-003',
        customerId: 'c2',
        amount: 5000000,
        paymentDate: now,
        paymentMethod: 'Bank BCA',
        isReversed: true, // Should be ignored in cash inflow
      ),
    ];

    final testExpenses = [
      ExpenseModel(
        id: 'e1',
        expenseNumber: 'EXP-001',
        title: 'Sewa Server Hetzner AX101',
        category: 'SERVER',
        amount: 1200000,
        expenseDate: now,
        recipient: 'Hetzner Online',
        paymentMethod: 'Transfer Bank Mandiri',
      ),
      ExpenseModel(
        id: 'e2',
        expenseNumber: 'EXP-002',
        title: 'Lisensi cPanel WHM',
        category: 'LICENSE',
        amount: 450000,
        expenseDate: now,
        recipient: 'cPanel Inc',
        paymentMethod: 'PayPal',
      ),
      ExpenseModel(
        id: 'e3',
        expenseNumber: 'EXP-003',
        title: 'Gaji Freelance Ops',
        category: 'WORKER',
        amount: 800000,
        expenseDate: now,
        recipient: 'Worker Dani',
        paymentMethod: 'BCA',
      ),
    ];

    final testInvoices = [
      InvoiceModel(
        id: 'inv-001',
        invoiceNumber: 'INV-2026-001',
        customerId: 'c1',
        items: [],
        subtotal: 2500000,
        total: 2500000,
        paidAmount: 2500000,
        status: 'paid',
        dueDate: now.add(const Duration(days: 5)),
      ),
      InvoiceModel(
        id: 'inv-002',
        invoiceNumber: 'INV-2026-002',
        customerId: 'c2',
        items: [],
        subtotal: 3000000,
        total: 3000000,
        paidAmount: 1500000,
        status: 'partial',
        dueDate: now.subtract(const Duration(days: 3)), // Overdue 3 days
      ),
      InvoiceModel(
        id: 'inv-004',
        invoiceNumber: 'INV-2026-004',
        customerId: 'c2',
        items: [],
        subtotal: 1000000,
        total: 1000000,
        paidAmount: 0,
        status: 'unpaid',
        dueDate: now.add(const Duration(days: 7)),
      ),
    ];

    test('Computes financial metrics accurately with proper inflow, outflow, and net profit', () {
      final bundle = repo.processFinancialData(
        horizon: TimeFilterHorizon.allTime,
        allPayments: testPayments,
        allExpenses: testExpenses,
        allInvoices: testInvoices,
        allCustomers: testCustomers,
      );

      // Inflow: 2.500.000 + 1.500.000 = 4.000.000 (p3 ignored because reversed)
      expect(bundle.metrics.totalInflow, 4000000);

      // Outflow: 1.200.000 + 450.000 + 800.000 = 2.450.000
      expect(bundle.metrics.totalOutflow, 2450000);

      // Net profit: 4.000.000 - 2.450.000 = 1.550.000
      expect(bundle.metrics.netProfit, 1550000);

      // Profit margin: 1.550.000 / 4.000.000 * 100 = 38.75%
      expect(bundle.metrics.profitMargin, closeTo(38.75, 0.01));

      // Outstanding receivables: inv-002 remaining 1.500.000 + inv-004 remaining 1.000.000 = 2.500.000
      expect(bundle.metrics.outstandingReceivables, 2500000);
      expect(bundle.metrics.unpaidInvoicesCount, 2);
    });

    test('Unified Cashflow Ledger correctly combines payments and expenses in chronological order', () {
      final bundle = repo.processFinancialData(
        horizon: TimeFilterHorizon.allTime,
        allPayments: testPayments,
        allExpenses: testExpenses,
        allInvoices: testInvoices,
        allCustomers: testCustomers,
      );

      // Total non-reversed payments (2) + expenses (3) = 5 items
      expect(bundle.ledger.length, 5);

      final inflows = bundle.ledger.where((item) => item.isInflow).toList();
      final outflows = bundle.ledger.where((item) => item.isOutflow).toList();

      expect(inflows.length, 2);
      expect(outflows.length, 3);

      // Checks customer name resolution
      final paymentItem = inflows.firstWhere((p) => p.partyName == 'PT Digital Solusindo');
      expect(paymentItem.amount, 2500000);
      expect(paymentItem.paymentMethod, 'Bank Mandiri');

      // Checks vendor resolution
      final expenseItem = outflows.firstWhere((e) => e.partyName == 'Hetzner Online');
      expect(expenseItem.amount, 1200000);
      expect(expenseItem.categoryLabel, 'Server & Infra');
    });

    test('Expense categories are grouped and sorted by largest expense', () {
      final bundle = repo.processFinancialData(
        horizon: TimeFilterHorizon.allTime,
        allPayments: testPayments,
        allExpenses: testExpenses,
        allInvoices: testInvoices,
        allCustomers: testCustomers,
      );

      expect(bundle.expenseCategories.length, 3);
      // SERVER (1.200.000) should be first
      expect(bundle.expenseCategories[0].category, 'SERVER');
      expect(bundle.expenseCategories[0].amount, 1200000);

      // WORKER (800.000) should be second
      expect(bundle.expenseCategories[1].category, 'WORKER');
      expect(bundle.expenseCategories[1].amount, 800000);

      // LICENSE (450.000) should be third
      expect(bundle.expenseCategories[2].category, 'LICENSE');
      expect(bundle.expenseCategories[2].amount, 450000);
    });

    test('Payment methods distribution reflects payment channels', () {
      final bundle = repo.processFinancialData(
        horizon: TimeFilterHorizon.allTime,
        allPayments: testPayments,
        allExpenses: testExpenses,
        allInvoices: testInvoices,
        allCustomers: testCustomers,
      );

      expect(bundle.paymentMethods.length, 2);
      final mandiri = bundle.paymentMethods.firstWhere((m) => m.methodName == 'Bank Mandiri');
      expect(mandiri.totalAmount, 2500000);
      expect(mandiri.transactionCount, 1);

      final qris = bundle.paymentMethods.firstWhere((m) => m.methodName == 'QRIS');
      expect(qris.totalAmount, 1500000);
      expect(qris.transactionCount, 1);
    });

    test('Aging receivables sorts overdue invoices first with overdue days', () {
      final bundle = repo.processFinancialData(
        horizon: TimeFilterHorizon.allTime,
        allPayments: testPayments,
        allExpenses: testExpenses,
        allInvoices: testInvoices,
        allCustomers: testCustomers,
      );

      expect(bundle.agingReceivables.length, 2);

      // inv-002 was overdue by 3 days
      final first = bundle.agingReceivables.first;
      expect(first.invoice.invoiceNumber, 'INV-2026-002');
      expect(first.isOverdue, isTrue);
      expect(first.daysOverdue >= 3, isTrue);
      expect(first.customerName, 'Budi Santoso');
      expect(first.remainingAmount, 1500000);
    });

    test('generateFinancialCsv exports valid CSV containing headers and ledger rows', () {
      final bundle = repo.processFinancialData(
        horizon: TimeFilterHorizon.allTime,
        allPayments: testPayments,
        allExpenses: testExpenses,
        allInvoices: testInvoices,
        allCustomers: testCustomers,
      );

      final csvContent = repo.generateFinancialCsv(bundle);

      expect(csvContent.contains('LAPORAN ARUS KAS & KEUANGAN FUCHURHOST SOLUTIONS'), isTrue);
      expect(csvContent.contains('RINGKASAN EKSEKUTIF KEUANGAN'), isTrue);
      expect(csvContent.contains('Total Kas Masuk (Inflow)'), isTrue);
      expect(csvContent.contains('Total Kas Keluar (Outflow)'), isTrue);
      expect(csvContent.contains('BUKU KAS & MUTASI TRANSAKSI TERPADU'), isTrue);
      expect(csvContent.contains('Sewa Server Hetzner AX101'), isTrue);
      expect(csvContent.contains('PT Digital Solusindo'), isTrue);
    });
  });
}
