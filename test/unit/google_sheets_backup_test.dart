import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/customers/models/customer_model.dart';
import 'package:fuchuragent/features/services/models/service_model.dart';
import 'package:fuchuragent/features/expenses/models/expense_model.dart';
import 'package:fuchuragent/features/invoices/models/invoice_model.dart';
import 'package:fuchuragent/features/payments/models/payment_model.dart';
import 'package:fuchuragent/features/settings/models/system_settings_model.dart';
import 'package:fuchuragent/features/settings/services/google_sheets_backup_service.dart';

void main() {
  group('GoogleSheetsBackupService Unit Tests', () {
    final service = GoogleSheetsBackupService();

    test('formatSheetDate should format dates into M/d/yyyy format', () {
      final date = DateTime(2026, 10, 18);
      expect(GoogleSheetsBackupService.formatSheetDate(date), '10/18/2026');

      final dateJan = DateTime(2026, 1, 5);
      expect(GoogleSheetsBackupService.formatSheetDate(dateJan), '1/5/2026');

      expect(GoogleSheetsBackupService.formatSheetDate(null), '');
    });

    test('formatVpsCurrency should format correctly with Rp and decimal places', () {
      expect(GoogleSheetsBackupService.formatVpsCurrency(77000), 'Rp77,000.00');
      expect(GoogleSheetsBackupService.formatVpsCurrency(1500000), 'Rp1,500,000.00');
      expect(GoogleSheetsBackupService.formatVpsCurrency(0), 'Rp0.00');
    });

    test('formatExpenseCurrency should format correctly for expense sheet', () {
      expect(GoogleSheetsBackupService.formatExpenseCurrency(30000), 'Rp30,000');
      expect(GoogleSheetsBackupService.formatExpenseCurrency(250000), 'Rp250,000');
    });

    test('convertToTsv should create tab-separated string ready for clipboard', () {
      final rows = [
        ['No', 'Nama', 'Nominal'],
        [1, 'VPS Snipe-it', 'Rp77,000.00'],
        [2, 'Perpanjangan Domain', 'Rp150,000.00'],
      ];
      final tsv = GoogleSheetsBackupService.convertToTsv(rows);

      final lines = tsv.split('\n');
      expect(lines.length, 3);
      expect(lines[0], 'No\tNama\tNominal');
      expect(lines[1], '1\tVPS Snipe-it\tRp77,000.00');
      expect(lines[2], '2\tPerpanjangan Domain\tRp150,000.00');
    });

    test('processBackupBundle should generate exact columns matching target spreadsheet', () {
      final mockCustomers = [
        CustomerModel(
          id: 'cust-101',
          sourceId: 'Cus-001',
          name: 'Iqbal Ramadan',
          phone: '081234567890',
          email: 'iqbal@example.com',
          status: 'active',
          notes: 'Pelanggan Utama',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      final mockServices = [
        VpsServiceModel(
          id: 'srv-001',
          customerId: 'cust-101',
          serviceName: 'vps.fuchurhost.id',
          packageName: 'Snipe-it Basic',
          domain: 'snipe.fuchur.my.id',
          price: 77000,
          billingCycleMonths: 1,
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 11, 1),
          deploymentType: 'Publish',
          worker: 'Iqbal',
          workerPaid: true,
          status: 'active',
          createdAt: DateTime(2026, 10, 1),
        ),
      ];

      final mockExpenses = [
        ExpenseModel(
          id: 'exp-001',
          title: 'Sewa Server Dedicated SG',
          amount: 500000,
          category: 'Server / VPS Node',
          expenseDate: DateTime(2026, 10, 5),
          notes: 'Biaya hosting bulanan',
          createdAt: DateTime(2026, 10, 5),
        ),
      ];

      final mockInvoices = [
        InvoiceModel(
          id: 'inv-001',
          invoiceNumber: 'INV-202610-001',
          customerId: 'cust-101',
          items: [
            InvoiceItem(description: 'Snipe-it Basic', unitPrice: 77000, quantity: 1, total: 77000),
          ],
          subtotal: 77000,
          discount: 0,
          total: 77000,
          paidAmount: 77000,
          status: 'paid',
          dueDate: DateTime(2026, 10, 15),
          notes: 'Tagihan bulan Oktober',
          createdAt: DateTime(2026, 10, 1),
        ),
      ];

      final mockPayments = [
        PaymentModel(
          id: 'pay-001',
          invoiceId: 'INV-202610-001',
          customerId: 'cust-101',
          amount: 77000,
          paymentMethod: 'Bank BCA',
          referenceNumber: 'TRX-998877',
          paymentDate: DateTime(2026, 10, 2),
          notes: 'Lunas via m-BCA',
          createdAt: DateTime(2026, 10, 2),
        ),
      ];

      final bundle = service.processBackupBundle(
        customers: mockCustomers,
        services: mockServices,
        expenses: mockExpenses,
        invoices: mockInvoices,
        payments: mockPayments,
      );

      // Verify VPS Sheet Structure
      expect(bundle.vpsSheetRows.first, [
        'No',
        'ID Customer',
        'Nomor HP',
        'Paket',
        'Domain',
        'Optional',
        'Nominal',
        'Payment Status',
        'Mulai',
        'Akhir',
        'Worker ',
        'Payment Worker',
        'Status',
      ]);
      expect(bundle.vpsSheetRows.length, 2);
      final vpsDataRow = bundle.vpsSheetRows[1];
      expect(vpsDataRow[0], 1);
      expect(vpsDataRow[1], 'Cus-001');
      expect(vpsDataRow[2], '081234567890');
      expect(vpsDataRow[3], 'Snipe-it Basic');
      expect(vpsDataRow[4], 'snipe.fuchur.my.id');
      expect(vpsDataRow[5], 'Publish');
      expect(vpsDataRow[6], 'Rp77,000.00');
      expect(vpsDataRow[7], 'Lunas');
      expect(vpsDataRow[8], '10/1/2026');
      expect(vpsDataRow[9], '11/1/2026');
      expect(vpsDataRow[10], 'Iqbal');
      expect(vpsDataRow[11], 'TRUE');
      expect(vpsDataRow[12], 'Active');

      // Verify Expense Sheet Structure
      expect(bundle.expenseSheetRows.first, ['No', 'Nama ', 'Total', 'Tanggal']);
      expect(bundle.expenseSheetRows.length, 2);
      final expDataRow = bundle.expenseSheetRows[1];
      expect(expDataRow[0], 1);
      expect(expDataRow[1], 'Sewa Server Dedicated SG');
      expect(expDataRow[2], 'Rp500,000');
      expect(expDataRow[3], '10/5/2026');

      // Verify Invoice Sheet Structure
      expect(bundle.invoiceSheetRows.first, [
        'No',
        'Nomor Invoice',
        'ID Customer',
        'Nama Pelanggan',
        'Subtotal',
        'Diskon',
        'Total Tagihan',
        'Terbayar',
        'Status',
        'Jatuh Tempo',
        'Catatan',
      ]);
      expect(bundle.invoiceSheetRows.length, 2);
      expect(bundle.invoiceSheetRows[1][3], 'Iqbal Ramadan');

      // Verify Payment Sheet Structure
      expect(bundle.paymentSheetRows.first, [
        'No',
        'ID Pembayaran',
        'Nomor Invoice',
        'Nama Pelanggan',
        'Nominal (Rp)',
        'Metode Pembayaran',
        'No Referensi',
        'Tanggal Bayar',
        'Catatan',
      ]);
      expect(bundle.paymentSheetRows.length, 2);
      expect(bundle.paymentSheetRows[1][4], 77000);

      // Verify CSV and TSV content
      expect(bundle.vpsCsv.isNotEmpty, true);
      expect(bundle.vpsTsv.contains('Rp77,000.00'), true);
      expect(bundle.expenseTsv.contains('Rp500,000'), true);
      expect(bundle.fullJsonSnapshot.contains('Fuchur Agent'), true);
    });

    test('generateAppsScriptCode should generate valid Google Apps Script with doPost', () {
      final code = GoogleSheetsBackupService.generateAppsScriptCode();
      expect(code.contains('function doPost(e)'), true);
      expect(code.contains('SpreadsheetApp.getActiveSpreadsheet()'), true);
      expect(code.contains('getSheetByName("VPS")'), true);
      expect(code.contains('getSheetByName("Pengeluaran")'), true);
      expect(code.contains('getSheetByName("Tagihan & Invoices")'), true);
      expect(code.contains('getSheetByName("Riwayat Pembayaran")'), true);
      expect(code.contains('1Rdcg6rgp4K7qBO328qeqHfzpaaYZjcRgvsI_OQGjLkE'), true);
    });

    test('SystemSettingsModel persists spreadsheetBackupUrl and spreadsheetWebhookUrl', () {
      final original = SystemSettingsModel.defaultSettings().copyWith(
        spreadsheetBackupUrl:
            'https://docs.google.com/spreadsheets/d/1Rdcg6rgp4K7qBO328qeqHfzpaaYZjcRgvsI_OQGjLkE/edit?usp=sharing',
        spreadsheetWebhookUrl: 'https://script.google.com/macros/s/AKfycbxTest/exec',
      );

      final map = original.toMap();
      expect(map['spreadsheetBackupUrl'], original.spreadsheetBackupUrl);
      expect(map['spreadsheetWebhookUrl'], original.spreadsheetWebhookUrl);

      final restored = SystemSettingsModel.fromMap(map);
      expect(restored.spreadsheetBackupUrl, original.spreadsheetBackupUrl);
      expect(restored.spreadsheetWebhookUrl, original.spreadsheetWebhookUrl);
    });
  });
}
