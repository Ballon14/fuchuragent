import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/customers/repositories/customer_repository.dart';

void main() {
  group('Customer ID Auto-Generation Sequence Tests', () {
    test('Generates CUS-001 for empty customer list', () {
      final nextId = CustomerRepository.calculateNextCustomerId([]);
      expect(nextId, equals('CUS-001'));
    });

    test('Generates next sequential ID from standard spreadsheet format (Cus-001 to Cus-020 -> CUS-021)', () {
      final existingIds = [
        'Cus-001',
        'Cus-002',
        'Cus-003',
        'Cus-004',
        'Cus-019',
        'Cus-020',
      ];
      final nextId = CustomerRepository.calculateNextCustomerId(existingIds);
      expect(nextId, equals('CUS-021'));
    });

    test('Handles out-of-order IDs and finds the true maximum sequence number', () {
      final existingIds = [
        'CUS-015',
        'Cus-002',
        'CUS-089',
        'Cus-010',
        'CUS-001',
      ];
      final nextId = CustomerRepository.calculateNextCustomerId(existingIds);
      expect(nextId, equals('CUS-090'));
    });

    test('Handles diverse ID variations: CUS-020, cus-20, CUS20, C-20', () {
      expect(CustomerRepository.calculateNextCustomerId(['cus-5', 'Cus-10']), equals('CUS-011'));
      expect(CustomerRepository.calculateNextCustomerId(['CUS25']), equals('CUS-026'));
      expect(CustomerRepository.calculateNextCustomerId(['C-12']), equals('CUS-013'));
      expect(CustomerRepository.calculateNextCustomerId(['99']), equals('CUS-100'));
    });

    test('Safely ignores blank, empty, and non-numeric strings', () {
      final existingIds = [
        '',
        '   ',
        'UNKNOWN',
        'CustomClient',
        'CUS-005',
      ];
      final nextId = CustomerRepository.calculateNextCustomerId(existingIds);
      expect(nextId, equals('CUS-006'));
    });

    test('Correctly formats 3-digit padding and transitions over 999', () {
      expect(CustomerRepository.calculateNextCustomerId(['CUS-099']), equals('CUS-100'));
      expect(CustomerRepository.calculateNextCustomerId(['CUS-999']), equals('CUS-1000'));
    });
  });
}
