import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/invoices/models/invoice_model.dart';
import 'package:fuchuragent/features/packages/models/package_model.dart';
import 'package:fuchuragent/features/services/models/service_model.dart';

void main() {
  group('Billing and Pricing Logic Tests', () {
    test('Calculates package discount accurately for 1, 3, 6, 12 months', () {
      final pkg = VpsPackageModel(
        id: 'basic',
        name: 'Basic',
        code: 'basic',
        vcpu: 1,
        ramGb: 1,
        storageGb: 20,
        basePrice: 100000,
        durationDiscounts: {
          1: 0.08,
          3: 0.10,
          6: 0.12,
          12: 0.15,
        },
      );

      // 1 month: 100k - 8% = 92,000
      expect(pkg.calculatePrice(1), equals(92000));
      // 3 months: 300k - 10% = 270,000
      expect(pkg.calculatePrice(3), equals(270000));
      // 6 months: 600k - 12% = 528,000
      expect(pkg.calculatePrice(6), equals(528000));
      // 12 months: 1.2M - 15% = 1,020,000
      expect(pkg.calculatePrice(12), equals(1020000));
    });

    test('Invoice remaining balance and partial/paid status', () {
      final invoice = InvoiceModel(
        id: 'inv-1',
        invoiceNumber: 'INV-202610-0001',
        customerId: 'cus-1',
        items: [
          InvoiceItem(description: 'VPS Standard', unitPrice: 150000, quantity: 1, total: 150000),
        ],
        subtotal: 150000,
        discount: 15000,
        total: 135000,
        paidAmount: 50000,
        status: 'partial',
        dueDate: DateTime(2026, 10, 25),
      );

      expect(invoice.remainingBalance, equals(85000));
      expect(invoice.isPaid, isFalse);
      expect(invoice.isPartial, isTrue);

      final fullyPaidInvoice = InvoiceModel(
        id: 'inv-1',
        invoiceNumber: 'INV-202610-0001',
        customerId: 'cus-1',
        items: [
          InvoiceItem(description: 'VPS Standard', unitPrice: 150000, quantity: 1, total: 150000),
        ],
        subtotal: 150000,
        discount: 15000,
        total: 135000,
        paidAmount: 135000,
        status: 'paid',
        dueDate: DateTime(2026, 10, 25),
      );

      expect(fullyPaidInvoice.remainingBalance, equals(0));
      expect(fullyPaidInvoice.isPaid, isTrue);
    });

    test('Overdue status detection when due date is past', () {
      final overdueInvoice = InvoiceModel(
        id: 'inv-2',
        invoiceNumber: 'INV-202610-0002',
        customerId: 'cus-2',
        items: [],
        subtotal: 100000,
        total: 100000,
        paidAmount: 0,
        status: 'unpaid',
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(overdueInvoice.isOverdue, isTrue);
    });
  });

  group('VPS Service Renewal Logic Tests', () {
    test('Service model detects active status and expiration properly', () {
      final activeSvc = VpsServiceModel(
        id: 'svc-1',
        customerId: 'cus-1',
        serviceName: 'VPS 1',
        domain: 'https://puskesmaspituruh.my.id',
        packageName: 'Basic 3 Bulan',
        price: 135000,
        status: 'active',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
      );

      expect(activeSvc.isActive, isTrue);
      expect(activeSvc.isExpired, isFalse);
      expect(activeSvc.daysUntilExpiry, greaterThan(0));

      final expiredSvc = VpsServiceModel(
        id: 'svc-2',
        customerId: 'cus-2',
        serviceName: 'VPS 2',
        domain: 'https://arkavue.buildsys.site',
        packageName: 'Snipe-it Basic',
        price: 77000,
        status: 'deactive',
        startDate: DateTime(2026, 7, 4),
        endDate: DateTime(2026, 8, 4),
      );

      expect(expiredSvc.isExpired, isTrue);
    });

    test('Separates service status from payment status', () {
      final svc = VpsServiceModel(
        id: 'svc-3',
        customerId: 'cus-3',
        serviceName: 'VPS 3',
        domain: 'https://smkn6lab.site',
        packageName: 'Basic 1 Bulan',
        price: 76000,
        status: 'active', // Service is running
      );

      // Payment status is in Invoice, not hardcoded on Service
      expect(svc.status, equals('active'));
    });
  });
}
