import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/customers/models/customer_model.dart';
import 'package:fuchuragent/features/services/models/service_model.dart';

void main() {
  group('Customer Dynamic Status Tests (Based on VPS Service Rentals)', () {
    final now = DateTime(2026, 10, 18, 12, 0);

    test('Customer with no VPS services is inactive (Nonaktif)', () {
      final status = CustomerModel.calculateStatusFromServices(
        services: [],
        now: now,
      );
      expect(status, equals('inactive'));
    });

    test('Customer with active, non-expired VPS service is active (Aktif)', () {
      final services = [
        VpsServiceModel(
          id: 'vps-1',
          customerId: 'cus-1',
          serviceName: 'VPS Ubuntu 24.04',
          domain: 'api.example.com',
          packageName: 'Pro Cloud',
          price: 250000,
          status: 'active',
          startDate: DateTime(2026, 9, 18),
          endDate: DateTime(2026, 11, 18), // Masa aktif masih berlaku
        ),
      ];

      final status = CustomerModel.calculateStatusFromServices(
        services: services,
        now: now,
      );
      expect(status, equals('active'));
    });

    test('Customer whose VPS service has expired is inactive (Nonaktif)', () {
      final services = [
        VpsServiceModel(
          id: 'vps-2',
          customerId: 'cus-2',
          serviceName: 'VPS Debian',
          domain: 'old.example.com',
          packageName: 'Basic Cloud',
          price: 150000,
          status: 'active',
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 9, 1), // Sudah kadaluarsa sebelum 'now' (18 Okt 2026)
        ),
      ];

      final status = CustomerModel.calculateStatusFromServices(
        services: services,
        now: now,
      );
      expect(status, equals('inactive'));
    });

    test('Customer with non-active service status (e.g. deactive/suspended) is inactive', () {
      final services = [
        VpsServiceModel(
          id: 'vps-3',
          customerId: 'cus-3',
          serviceName: 'VPS Windows',
          domain: 'win.example.com',
          packageName: 'Enterprise Cloud',
          price: 500000,
          status: 'deactive', // Status layanan nonaktif
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 12, 1),
        ),
      ];

      final status = CustomerModel.calculateStatusFromServices(
        services: services,
        now: now,
      );
      expect(status, equals('inactive'));
    });

    test('Customer with multiple services where one is active & not expired is active', () {
      final services = [
        VpsServiceModel(
          id: 'vps-exp',
          customerId: 'cus-4',
          serviceName: 'VPS Lama',
          domain: 'old.site',
          packageName: 'Standard',
          price: 100000,
          status: 'active',
          endDate: DateTime(2026, 10, 10), // Kadaluarsa
        ),
        VpsServiceModel(
          id: 'vps-active',
          customerId: 'cus-4',
          serviceName: 'VPS Baru',
          domain: 'new.site',
          packageName: 'Pro',
          price: 300000,
          status: 'active',
          endDate: DateTime(2026, 11, 20), // Masih aktif
        ),
      ];

      final status = CustomerModel.calculateStatusFromServices(
        services: services,
        now: now,
      );
      expect(status, equals('active'));
    });

    test('Archived customer preserves archived status regardless of services', () {
      final services = [
        VpsServiceModel(
          id: 'vps-5',
          customerId: 'cus-5',
          serviceName: 'VPS Active',
          domain: 'archived.site',
          packageName: 'Pro',
          price: 300000,
          status: 'active',
          endDate: DateTime(2026, 12, 1),
        ),
      ];

      final status = CustomerModel.calculateStatusFromServices(
        services: services,
        isArchived: true,
        now: now,
      );
      expect(status, equals('archived'));
    });

    test('Dynamic customer status mapping across customer list', () {
      final customers = [
        CustomerModel(id: 'c1', name: 'PT Maju Bersama', phone: '08123456789'),
        CustomerModel(id: 'c2', name: 'CV Abadi', phone: '08123456780'),
        CustomerModel(id: 'c3', name: 'Klinik Sehat', phone: '08123456781', status: 'archived'),
      ];

      final allServices = [
        VpsServiceModel(
          id: 's1',
          customerId: 'c1',
          serviceName: 'VPS 1',
          domain: 'maju.com',
          packageName: 'Pro',
          price: 200000,
          status: 'active',
          endDate: now.add(const Duration(days: 30)), // Aktif
        ),
        VpsServiceModel(
          id: 's2',
          customerId: 'c2',
          serviceName: 'VPS 2',
          domain: 'abadi.com',
          packageName: 'Basic',
          price: 100000,
          status: 'active',
          endDate: now.subtract(const Duration(days: 5)), // Kadaluarsa
        ),
      ];

      final activeCustomerIds = allServices
          .where((s) => s.isActive && s.endDate != null && s.endDate!.isAfter(now))
          .map((s) => s.customerId)
          .toSet();

      final evaluatedCustomers = customers.map((c) {
        final dynamicStatus = c.isArchived
            ? 'archived'
            : (activeCustomerIds.contains(c.id) ? 'active' : 'inactive');
        return c.copyWith(status: dynamicStatus);
      }).toList();

      expect(evaluatedCustomers.firstWhere((c) => c.id == 'c1').status, equals('active'));
      expect(evaluatedCustomers.firstWhere((c) => c.id == 'c2').status, equals('inactive'));
      expect(evaluatedCustomers.firstWhere((c) => c.id == 'c3').status, equals('archived'));
    });
  });
}
