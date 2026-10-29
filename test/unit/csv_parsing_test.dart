import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/core/constants/app_constants.dart';
import 'package:fuchuragent/features/imports/models/import_models.dart';

void main() {
  group('CSV Parsing and Normalization Tests', () {
    test('Correctly parses Rupiah currency strings to integer', () {
      expect(AppConstants.parseRupiah('Rp77,000.00'), equals(77000));
      expect(AppConstants.parseRupiah('Rp135,000.00'), equals(135000));
      expect(AppConstants.parseRupiah('Rp76,000.00'), equals(76000));
      expect(AppConstants.parseRupiah('Rp46,000.00'), equals(46000));
      expect(AppConstants.parseRupiah(''), equals(0));
    });

    test('Correctly formats integer to Rupiah currency string', () {
      final formatted = AppConstants.formatRupiah(135000);
      expect(formatted.contains('135.000'), isTrue);
      expect(formatted.contains('Rp'), isTrue);
    });


    test('Identifies valid customer row and normalizes "Actice" typo to "active"', () {
      final rawRow = [
        '7',
        'Cus-007',
        '0823-2688-8001',
        'Basic 3 Bulan',
        'https://puskesmaspituruh.my.id',
        'Publish',
        'Rp135,000.00',
        'Lunas',
        '7/3/2026',
        '10/3/2026',
        'Iqbal',
        'TRUE',
        'Actice',
      ];

      final parsed = CsvCustomerRow.fromRawList(7, rawRow);
      expect(parsed.isValid, isTrue);
      expect(parsed.isPlaceholder, isFalse);
      expect(parsed.sourceId, equals('Cus-007'));
      expect(parsed.parsedNominal, equals(135000));
      expect(parsed.normalizedStatus, equals('active'));
      expect(parsed.workerPaid, isTrue);
    });

    test('Identifies empty placeholder row (Cus-011) and flags as placeholder', () {
      final placeholderRow = [
        '11',
        'Cus-011',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'FALSE',
        '',
      ];

      final parsed = CsvCustomerRow.fromRawList(11, placeholderRow);
      expect(parsed.isPlaceholder, isTrue);
      expect(parsed.isValid, isFalse);
      expect(parsed.validationErrors, contains('Data baris placeholder kosong.'));
    });
  });
}
