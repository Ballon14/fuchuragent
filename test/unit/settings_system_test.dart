import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/settings/models/system_settings_model.dart';
import 'package:fuchuragent/features/services/services/whatsapp_reminder_service.dart';
import 'package:fuchuragent/features/customers/models/customer_model.dart';
import 'package:fuchuragent/features/services/models/service_model.dart';

void main() {
  group('SystemSettingsModel Tests', () {
    test('defaultSettings should initialize with standard values', () {
      final settings = SystemSettingsModel.defaultSettings();

      expect(settings.companyName, 'FuchurHost Solutions');
      expect(settings.brandName, 'Fuchur Agent');
      expect(settings.supportEmail, 'support@fuchuragent.id');
      expect(settings.paymentMethods.length, 1);
      expect(settings.paymentMethods.first.name, 'Bank Jago');
      expect(settings.paymentMethods.first.accountNumber, '1078-5455-7360');
      expect(settings.paymentMethods.first.accountHolder, 'MUHAMMAD IQBAL FATCHURROHMAN');
      expect(settings.paymentMethods.first.isDefault, true);
      expect(settings.bankAccounts.length, 1);
      expect(settings.enableDueReminders, true);

      expect(settings.reminderDays, containsAll([7, 3, 1, 0]));
      expect(settings.currencyCode, 'IDR');
      expect(settings.defaultItemsPerPage, 10);
    });

    test('Serialization toMap and fromMap should preserve all fields and paymentMethods', () {
      final original = SystemSettingsModel.defaultSettings().copyWith(
        companyName: 'Custom Host Indo',
        brandName: 'CustomAgent',
        currencyCode: 'USD',
        defaultItemsPerPage: 25,
        reminderHour: 10,
        paymentMethods: [
          const PaymentMethodModel(
            id: 'pm-bsi',
            name: 'Bank Syariah (BSI)',
            accountNumber: '9988776655',
            accountHolder: 'Custom Host',
            type: 'bank_transfer',
            notes: 'Transfer antar bank syariah',
            isActive: true,
            isDefault: true,
          ),
        ],
      );

      final map = original.toMap();
      final restored = SystemSettingsModel.fromMap(map);

      expect(restored.companyName, 'Custom Host Indo');
      expect(restored.brandName, 'CustomAgent');
      expect(restored.currencyCode, 'USD');
      expect(restored.defaultItemsPerPage, 25);
      expect(restored.reminderHour, 10);
      expect(restored.paymentMethods.length, 1);
      expect(restored.paymentMethods.first.name, 'Bank Syariah (BSI)');
      expect(restored.paymentMethods.first.accountNumber, '9988776655');
      expect(restored.paymentMethods.first.notes, 'Transfer antar bank syariah');
    });

    test('PaymentMethodModel allows dynamic modification of account number (rekening) without affecting pricing', () {
      const initialMethod = PaymentMethodModel(
        id: 'pm-bca',
        name: 'Bank BCA',
        accountNumber: '1111222233',
        accountHolder: 'Fuchur Host Indo',
        type: 'bank_transfer',
        isActive: true,
        isDefault: true,
      );

      expect(initialMethod.formattedDisplay, 'Bank BCA - 1111222233 (a.n Fuchur Host Indo)');

      // User changes rekening dynamically in Settings
      final updatedMethod = initialMethod.copyWith(
        accountNumber: '9999888877',
        accountHolder: 'PT Fuchur Solusi Digital',
      );

      expect(updatedMethod.accountNumber, '9999888877');
      expect(updatedMethod.accountHolder, 'PT Fuchur Solusi Digital');
      expect(updatedMethod.formattedDisplay, 'Bank BCA - 9999888877 (a.n PT Fuchur Solusi Digital)');
    });

    test('BankAccountModel serialization should work correctly', () {
      const bank = BankAccountModel(
        id: 'b-1',
        bankName: 'Bank Jago',
        accountNumber: '1029384756',
        accountHolder: 'Agent Admin',
        isDefault: true,
      );

      final map = bank.toMap();
      final fromMap = BankAccountModel.fromMap(map);

      expect(fromMap.id, 'b-1');
      expect(fromMap.bankName, 'Bank Jago');
      expect(fromMap.accountNumber, '1029384756');
      expect(fromMap.accountHolder, 'Agent Admin');
      expect(fromMap.isDefault, true);
    });

    test('WhatsAppReminderService integrates with dynamic payment method accounts', () {
      final customSettings = SystemSettingsModel.defaultSettings().copyWith(
        brandName: 'Mega Cloud Agent',
        waGreeting: 'Salam hangat untuk Kak *{name}*,',
        paymentMethods: const [
          PaymentMethodModel(
            id: 'pm-bni',
            name: 'Bank BNI',
            accountNumber: '7788990011',
            accountHolder: 'Mega Cloud PT',
            isDefault: true,
          ),
        ],
      );

      final customer = CustomerModel(
        id: 'cust-1',
        name: 'Ahmad Dahlan',
        phone: '08123456789',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final service = VpsServiceModel(
        id: 'srv-1',
        customerId: 'cust-1',
        packageId: 'pkg-1',
        packageName: 'Pro Cloud',
        serviceName: 'VPS Ahmad',
        domain: 'ahmad-store.com',
        vcpu: 4,
        ramGb: 8,
        storageGb: 160,
        status: 'active',
        billingCycleMonths: 1,
        price: 250000,
        startDate: DateTime.now().subtract(const Duration(days: 23)),
        endDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final message = WhatsAppReminderService.generateExpiringSoonTemplate(
        customer: customer,
        service: service,
        settings: customSettings,
      );

      expect(message, contains('Salam hangat untuk Kak *Ahmad Dahlan*,'));
      expect(message, contains('Mega Cloud Agent'));
      expect(message, contains('Bank BNI: *7788990011* a.n *Mega Cloud PT*'));
      expect(message, contains('ahmad-store.com'));
      expect(message, contains('250.000'));
    });
  });
}
