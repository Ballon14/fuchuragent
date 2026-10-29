import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/customers/models/customer_model.dart';
import 'package:fuchuragent/features/invoices/models/invoice_model.dart';
import 'package:fuchuragent/features/services/models/service_model.dart';
import 'package:fuchuragent/features/services/services/whatsapp_reminder_service.dart';
import 'package:fuchuragent/features/settings/models/system_settings_model.dart';

void main() {
  group('WhatsAppReminderService Phone Normalization Tests', () {
    test('Normalizes 08 prefix to 628', () {
      expect(
        WhatsAppReminderService.normalizePhoneNumber('081234567890'),
        equals('6281234567890'),
      );
    });

    test('Normalizes numbers with spaces, hyphens, and + symbol', () {
      expect(
        WhatsAppReminderService.normalizePhoneNumber('+62 812-3456-7890'),
        equals('6281234567890'),
      );
    });

    test('Normalizes 8 prefix to 628', () {
      expect(
        WhatsAppReminderService.normalizePhoneNumber('8123456789'),
        equals('628123456789'),
      );
    });

    test('Preserves already normalized 628 number', () {
      expect(
        WhatsAppReminderService.normalizePhoneNumber('6285712345678'),
        equals('6285712345678'),
      );
    });
  });

  group('WhatsApp Reminder Template Generation Tests', () {
    final sampleCustomer = CustomerModel(
      id: 'cust-1',
      sourceId: 'CUS-001',
      name: 'Budi Santoso',
      phone: '08123456789',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleExpiringService = VpsServiceModel(
      id: 'svc-1',
      customerId: 'cust-1',
      serviceName: 'VPS Toko Online',
      domain: 'tokoonline.com',
      packageName: 'Standard',
      vcpu: 2,
      ramGb: 2,
      storageGb: 40,
      price: 150000,
      billingCycleMonths: 1,
      startDate: DateTime.now().subtract(const Duration(days: 25)),
      endDate: DateTime.now().add(const Duration(days: 5)),
      status: 'active',
      deploymentType: 'Publish',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleExpiredService = VpsServiceModel(
      id: 'svc-2',
      customerId: 'cust-1',
      serviceName: 'VPS Landing Page',
      domain: 'landingpage.id',
      packageName: 'Basic',
      vcpu: 1,
      ramGb: 1,
      storageGb: 20,
      price: 80000,
      billingCycleMonths: 1,
      startDate: DateTime.now().subtract(const Duration(days: 40)),
      endDate: DateTime.now().subtract(const Duration(days: 2)),
      status: 'deactive',
      deploymentType: 'Publish',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sampleSettings = SystemSettingsModel.defaultSettings().copyWith(
      paymentMethods: const [
        PaymentMethodModel(
          id: 'pm-1',
          name: 'Bank BCA',
          accountNumber: '1234567890',
          accountHolder: 'Fuchur Cloud Indo',
          isDefault: true,
        ),
      ],
    );

    test('Expiring soon template contains customer name, domain, days left, and bank info when configured', () {
      final message = WhatsAppReminderService.generateExpiringSoonTemplate(
        customer: sampleCustomer,
        service: sampleExpiringService,
        settings: sampleSettings,
      );

      expect(message, contains('Budi Santoso'));
      expect(message, contains('tokoonline.com'));
      expect(message, contains('Standard'));
      expect(message, contains('150.000'));
      expect(message, contains('Bank BCA'));
      expect(message, contains('1234567890'));
      expect(message, contains('Fuchur Cloud Indo'));
      expect(message, contains('hari lagi'));
    });

    test('Expiring soon template does not contain bank section if no payment methods configured', () {
      final message = WhatsAppReminderService.generateExpiringSoonTemplate(
        customer: sampleCustomer,
        service: sampleExpiringService,
      );

      expect(message, contains('Budi Santoso'));
      expect(message, contains('tokoonline.com'));
      expect(message, isNot(contains('Rekening Pembayaran')));
    });

    test('Expired template clearly warns service is inactive and urges renewal', () {
      final message = WhatsAppReminderService.generateExpiredTemplate(
        customer: sampleCustomer,
        service: sampleExpiredService,
        settings: sampleSettings,
      );

      expect(message, contains('Budi Santoso'));
      expect(message, contains('landingpage.id'));
      expect(message, contains('berakhir'));
      expect(message, contains('Kedaluwarsa / Nonaktif'));
      expect(message, contains('80.000'));
      expect(message, contains('Bank BCA'));
      expect(message, contains('1234567890'));
    });

    test('Invoice reminder template contains invoice number and total amount', () {
      final invoice = InvoiceModel(
        id: 'inv-1',
        invoiceNumber: 'INV-2026-0042',
        customerId: 'cust-1',
        serviceId: 'svc-1',
        items: [
          InvoiceItem(
            description: 'Perpanjangan Layanan VPS - tokoonline.com',
            unitPrice: 150000,
            quantity: 1,
            total: 150000,
          )
        ],
        subtotal: 150000,
        discount: 0,
        total: 150000,
        paidAmount: 0,
        status: 'unpaid',
        issuedAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 3)),
      );

      final message = WhatsAppReminderService.generateInvoiceReminderTemplate(
        customer: sampleCustomer,
        invoice: invoice,
        settings: sampleSettings,
      );

      expect(message, contains('Budi Santoso'));
      expect(message, contains('INV-2026-0042'));
      expect(message, contains('150.000'));
      expect(message, contains('Bank BCA'));
      expect(message, contains('1234567890'));
    });


    test('buildWhatsAppUri creates correct wa.me link with encoded text', () {
      final uri = WhatsAppReminderService.buildWhatsAppUri('08123456789', 'Halo *Budi*!');

      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('wa.me'));
      expect(uri.path, equals('/628123456789'));
      expect(uri.queryParameters['text'], equals('Halo *Budi*!'));
    });
  });
}
