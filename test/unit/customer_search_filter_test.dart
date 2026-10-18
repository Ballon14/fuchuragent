import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/customers/models/customer_model.dart';

void main() {
  group('Customer Search & Filtering Logic Tests', () {
    final sampleCustomers = [
      CustomerModel(
        id: '1',
        sourceId: 'Cus-001',
        name: 'Arkavue Solutions',
        phone: '0851-9822-6204',
        email: 'admin@arkavue.site',
        status: 'active',
      ),
      CustomerModel(
        id: '2',
        sourceId: 'Cus-007',
        name: 'Puskesmas Pituruh',
        phone: '0823-2688-8001',
        email: 'info@pituruh.my.id',
        status: 'active',
      ),
      CustomerModel(
        id: '3',
        sourceId: 'Cus-010',
        name: 'SMKN 6 Purworejo',
        phone: '0895-2577-7657',
        email: 'lab@smkn6lab.site',
        status: 'inactive',
      ),
    ];

    List<CustomerModel> filterCustomers(
      List<CustomerModel> list, {
      String query = '',
      String status = 'all',
    }) {
      var result = list;
      if (status != 'all') {
        result = result.where((c) => c.status.toLowerCase() == status.toLowerCase()).toList();
      }
      if (query.trim().isNotEmpty) {
        final q = query.toLowerCase().trim();
        result = result.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              c.sourceId.toLowerCase().contains(q) ||
              (c.email?.toLowerCase().contains(q) ?? false);
        }).toList();
      }
      return result;
    }

    test('Searches customer by partial name (case-insensitive)', () {
      final results = filterCustomers(sampleCustomers, query: 'puskesmas');
      expect(results.length, equals(1));
      expect(results.first.name, equals('Puskesmas Pituruh'));
    });

    test('Searches customer by WhatsApp / phone digits', () {
      final results = filterCustomers(sampleCustomers, query: '9822');
      expect(results.length, equals(1));
      expect(results.first.sourceId, equals('Cus-001'));
    });

    test('Searches customer by Customer ID (Cus-010)', () {
      final results = filterCustomers(sampleCustomers, query: 'Cus-010');
      expect(results.length, equals(1));
      expect(results.first.name, equals('SMKN 6 Purworejo'));
    });

    test('Filters customer by status (active vs inactive)', () {
      final activeResults = filterCustomers(sampleCustomers, status: 'active');
      expect(activeResults.length, equals(2));

      final inactiveResults = filterCustomers(sampleCustomers, status: 'inactive');
      expect(inactiveResults.length, equals(1));
      expect(inactiveResults.first.sourceId, equals('Cus-010'));
    });

    test('Returns empty list when no customer matches query', () {
      final results = filterCustomers(sampleCustomers, query: 'NonExistentPersonXYZ');
      expect(results.isEmpty, isTrue);
    });
  });
}
