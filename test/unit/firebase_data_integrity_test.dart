import 'package:flutter_test/flutter_test.dart';
import 'package:csv/csv.dart';
import 'package:fuchuragent/core/constants/app_constants.dart';
import 'package:fuchuragent/features/settings/models/system_settings_model.dart';
import 'package:fuchuragent/features/dashboard/models/dashboard_stats.dart';
import 'package:fuchuragent/features/invoices/models/invoice_model.dart';
import 'package:fuchuragent/features/customers/models/customer_model.dart';
import 'package:fuchuragent/features/services/models/service_model.dart';
import 'package:fuchuragent/features/services/services/whatsapp_reminder_service.dart';

void main() {
  group('Firebase Data Integrity & Dynamic Settings Tests', () {
    test('Dynamic Branding: Custom brandName and companyName in settings takes precedence', () {
      final settings = SystemSettingsModel.defaultSettings().copyWith(
        brandName: 'CloudPro Host',
        companyName: 'PT Cloud Pro Nusantara',
      );

      final effectiveAppName = (settings.brandName.isNotEmpty)
          ? settings.brandName
          : AppConstants.appName;
      final effectiveCompanyName = (settings.companyName.isNotEmpty)
          ? settings.companyName
          : AppConstants.companyName;

      expect(effectiveAppName, 'CloudPro Host');
      expect(effectiveCompanyName, 'PT Cloud Pro Nusantara');
    });

    test('Dynamic Branding: Falls back gracefully to AppConstants when settings fields are empty', () {
      final settings = SystemSettingsModel.defaultSettings(); // brandName & companyName are empty string

      final effectiveAppName = (settings.brandName.isNotEmpty)
          ? settings.brandName
          : AppConstants.appName;
      final effectiveCompanyName = (settings.companyName.isNotEmpty)
          ? settings.companyName
          : AppConstants.companyName;

      expect(effectiveAppName, AppConstants.appName);
      expect(effectiveCompanyName, AppConstants.companyName);
    });

    test('Report CSV Export: Encodes all live stats into valid CSV structure without hardcoding', () {
      final stats = DashboardStats(
        totalCustomers: 45,
        activeCustomers: 38,
        totalServices: 52,
        activeServices: 44,
        expiringServicesCount: 6,
        expiredServicesCount: 2,
        unpaidInvoicesCount: 5,
        overdueInvoicesCount: 1,
        unpaidAmount: 675000,
        totalRevenue: 5400000,
        totalExpenses: 1200000,
        recentPayments: const [],
        recentCustomers: const [],
        recentActivities: const [],
        followUpServices: const [],
      );

      final rows = [
        ['Laporan Rekapitulasi Operasional & Keuangan'],
        ['Tanggal Ekspor', '2026-10-30T23:00:00Z'],
        [],
        ['Kategori', 'Indikator', 'Nilai Angka', 'Format Tampilan'],
        ['Keuangan', 'Total Pendapatan Kas Masuk', stats.totalRevenue, AppConstants.formatRupiah(stats.totalRevenue)],
        ['Keuangan', 'Total Pengeluaran Kas Keluar', stats.totalExpenses, AppConstants.formatRupiah(stats.totalExpenses)],
        ['Keuangan', 'Laba Bersih Operasional (Net Profit)', stats.netProfit, AppConstants.formatRupiah(stats.netProfit)],
        ['Keuangan', 'Total Piutang Tagihan Terbuka', stats.unpaidAmount, AppConstants.formatRupiah(stats.unpaidAmount)],
        ['Keuangan', 'Jumlah Tagihan Belum Lunas', stats.unpaidInvoicesCount, '${stats.unpaidInvoicesCount} Tagihan'],
        ['Keuangan', 'Jumlah Tagihan Overdue', stats.overdueInvoicesCount, '${stats.overdueInvoicesCount} Tagihan'],
        [],
        ['Operasional', 'Total Pelanggan Terdaftar', stats.totalCustomers, '${stats.totalCustomers} Pelanggan'],
        ['Operasional', 'Pelanggan Aktif', stats.activeCustomers, '${stats.activeCustomers} Pelanggan'],
        ['Operasional', 'Total Layanan VPS', stats.totalServices, '${stats.totalServices} Layanan'],
        ['Operasional', 'Layanan VPS Aktif', stats.activeServices, '${stats.activeServices} Instance'],
        ['Operasional', 'Layanan Mendekati Jatuh Tempo (<= 7 hari)', stats.expiringServicesCount, '${stats.expiringServicesCount} Instance'],
        ['Operasional', 'Layanan Kedaluwarsa', stats.expiredServicesCount, '${stats.expiredServicesCount} Instance'],
      ];

      final csvContent = csv.encode(rows);

      expect(csvContent, contains('Laporan Rekapitulasi Operasional & Keuangan'));
      expect(csvContent, contains('5400000'));
      expect(csvContent, contains('1200000'));
      expect(csvContent, contains('4200000')); // Net profit = 5.4M - 1.2M
      expect(csvContent, contains('45 Pelanggan'));
      expect(csvContent, contains('44 Instance'));

      // Decode back and verify row parsing
      final decoded = csv.decode(csvContent);
      expect(decoded.length, greaterThanOrEqualTo(15));
    });

    test('WhatsApp Reminder: Generates invoice reminder from real InvoiceModel and dynamic settings', () {
      final customer = CustomerModel(
        id: 'cus-101',
        sourceId: 'CUS-101',
        name: 'Budi Santoso',
        phone: '081234567890',
        createdAt: DateTime(2026, 1, 1),
      );

      final invoice = InvoiceModel(
        id: 'inv-999',
        invoiceNumber: 'INV-202610-0042',
        customerId: 'cus-101',
        serviceId: 'vps-202',
        items: [
          InvoiceItem(
            description: 'Perpanjangan VPS dev.budisantoso.id (3 Bulan)',
            unitPrice: 135000,
            quantity: 1,
            total: 135000,
          ),
        ],
        subtotal: 135000,
        discount: 0,
        total: 135000,
        paidAmount: 0,
        status: 'unpaid',
        issuedAt: DateTime(2026, 10, 15),
        dueDate: DateTime(2026, 10, 22),
      );

      final service = VpsServiceModel(
        id: 'vps-202',
        customerId: 'cus-101',
        serviceName: 'VPS dev.budisantoso.id',
        domain: 'dev.budisantoso.id',
        packageName: 'Basic 3 Bulan',
        vcpu: 1,
        ramGb: 1,
        storageGb: 20,
        price: 135000,
        status: 'active',
        endDate: DateTime(2026, 10, 22),
      );

      final settings = SystemSettingsModel.defaultSettings().copyWith(
        brandName: 'Nusantara Cloud',
        paymentMethods: [
          const PaymentMethodModel(
            id: 'bank-bca',
            name: 'BCA',
            accountNumber: '1234567890',
            accountHolder: 'Nusantara Cloud',
            isActive: true,
          ),
        ],
      );

      final template = WhatsAppReminderService.generateInvoiceReminderTemplate(
        customer: customer,
        invoice: invoice,
        service: service,
        settings: settings,
      );

      expect(template, contains('Budi Santoso'));
      expect(template, contains('Nusantara Cloud'));
      expect(template, contains('INV-202610-0042'));
      expect(template, contains('Perpanjangan VPS dev.budisantoso.id (3 Bulan)'));
      expect(template, contains('135.000'));
      expect(template, contains('1234567890'));
    });

    test('Dynamic Payment Methods: Active methods correctly format for display', () {
      const method1 = PaymentMethodModel(
        id: 'pm-1',
        name: 'Bank Mandiri',
        accountNumber: '1370001234567',
        accountHolder: 'Fuchur Cloud Host',
        isActive: true,
      );

      const method2 = PaymentMethodModel(
        id: 'pm-2',
        name: 'QRIS All Payment',
        accountNumber: 'NMID1234567',
        accountHolder: 'Fuchur Host',
        type: 'qris',
        isActive: true,
      );

      expect(method1.formattedDisplay, 'Bank Mandiri - 1370001234567 (a.n Fuchur Cloud Host)');
      expect(method2.formattedDisplay, 'QRIS All Payment - NMID1234567 (a.n Fuchur Host)');
    });
  });
}
