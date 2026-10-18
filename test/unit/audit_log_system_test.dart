import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/audit/models/activity_log_model.dart';
import 'package:fuchuragent/features/audit/repositories/audit_repository.dart';

void main() {
  group('ActivityLogModel Tests', () {
    test('ActivityLogModel fromMap and toMap round-trip', () {
      final now = DateTime(2026, 10, 18, 14, 25);
      final log = ActivityLogModel(
        id: 'log-001',
        actorId: 'user-abc',
        actorName: 'Ahmad Staff',
        action: 'CREATE_SERVICE',
        category: 'SERVICES',
        details: 'Menambahkan layanan VPS: srv1.host.com (RAM 4GB)',
        targetId: 'vps-123',
        timestamp: now,
      );

      final map = log.toMap();
      expect(map['actorId'], equals('user-abc'));
      expect(map['actorName'], equals('Ahmad Staff'));
      expect(map['action'], equals('CREATE_SERVICE'));
      expect(map['category'], equals('SERVICES'));
      expect(map['details'], contains('srv1.host.com'));
      expect(map['targetId'], equals('vps-123'));

      final restored = ActivityLogModel.fromMap('log-001', {
        'actorId': map['actorId'],
        'actorName': map['actorName'],
        'action': map['action'],
        'category': map['category'],
        'details': map['details'],
        'targetId': map['targetId'],
        'timestamp': now,
      });

      expect(restored.id, equals('log-001'));
      expect(restored.actorName, equals('Ahmad Staff'));
      expect(restored.action, equals('CREATE_SERVICE'));
      expect(restored.category, equals('SERVICES'));
      expect(restored.targetId, equals('vps-123'));
      expect(restored.timestamp, equals(now));
    });

    test('ActivityLogModel copyWith correctly overrides properties', () {
      final log = ActivityLogModel(
        id: 'log-002',
        actorId: 'admin-1',
        actorName: 'Super Admin',
        action: 'UPDATE_ROLE',
        category: 'SECURITY',
        details: 'Mengubah role staf menjadi admin',
      );

      final updated = log.copyWith(
        details: 'Mengubah role staf Ahmad menjadi admin',
        targetId: 'user-789',
      );

      expect(updated.id, equals('log-002'));
      expect(updated.action, equals('UPDATE_ROLE'));
      expect(updated.targetId, equals('user-789'));
      expect(updated.details, equals('Mengubah role staf Ahmad menjadi admin'));
      expect(updated.actorName, equals('Super Admin'));
    });
  });

  group('AuditRepository Filtering and Search Tests', () {
    final sampleLogs = [
      ActivityLogModel(
        id: '1',
        actorId: 'admin-1',
        actorName: 'Budi Santoso',
        action: 'CREATE_CUSTOMER',
        category: 'CUSTOMERS',
        details: 'Menambahkan pelanggan baru: PT Sukses Mandiri (CUS-021)',
        targetId: 'CUS-021',
        timestamp: DateTime(2026, 10, 18, 10, 0),
      ),
      ActivityLogModel(
        id: '2',
        actorId: 'staff-1',
        actorName: 'Citra Staff',
        action: 'CREATE_SERVICE',
        category: 'SERVICES',
        details: 'Menambahkan layanan VPS: cloud.sukses.id (Paket Pro 8GB)',
        targetId: 'srv-101',
        timestamp: DateTime(2026, 10, 18, 11, 0),
      ),
      ActivityLogModel(
        id: '3',
        actorId: 'staff-1',
        actorName: 'Citra Staff',
        action: 'CREATE_INVOICE',
        category: 'FINANCE',
        details: 'Tagihan INV-202610-0012 dibuat sejumlah Rp450.000',
        targetId: 'inv-301',
        timestamp: DateTime(2026, 10, 18, 12, 0),
      ),
      ActivityLogModel(
        id: '4',
        actorId: 'admin-1',
        actorName: 'Budi Santoso',
        action: 'RECORD_PAYMENT',
        category: 'FINANCE',
        details: 'Pembayaran Rp450.000 dicatat untuk tagihan INV-202610-0012 (Transfer Bank)',
        targetId: 'pay-401',
        timestamp: DateTime(2026, 10, 18, 13, 0),
      ),
      ActivityLogModel(
        id: '5',
        actorId: 'superadmin',
        actorName: 'Iqbal Admin',
        action: 'UPDATE_ROLE',
        category: 'SECURITY',
        details: 'Mengubah hak akses pengguna citra@fuchurhost.com menjadi admin',
        targetId: 'user-501',
        timestamp: DateTime(2026, 10, 18, 14, 0),
      ),
    ];

    test('Filters by category correctly', () {
      final financeLogs = AuditRepository.filterLogs(sampleLogs, categoryFilter: 'FINANCE');
      expect(financeLogs.length, equals(2));
      expect(financeLogs.every((l) => l.category == 'FINANCE'), isTrue);

      final customerLogs = AuditRepository.filterLogs(sampleLogs, categoryFilter: 'CUSTOMERS');
      expect(customerLogs.length, equals(1));
      expect(customerLogs.first.action, equals('CREATE_CUSTOMER'));

      final allLogs = AuditRepository.filterLogs(sampleLogs, categoryFilter: 'all');
      expect(allLogs.length, equals(5));
    });

    test('Searches by actor name keyword (case-insensitive)', () {
      final citraLogs = AuditRepository.filterLogs(sampleLogs, searchQuery: 'citra');
      expect(citraLogs.length, equals(3)); // 2 performed by Citra + 1 mention in security details
    });

    test('Searches by details content keyword (e.g. invoice number or domain)', () {
      final invoiceLogs = AuditRepository.filterLogs(sampleLogs, searchQuery: 'INV-202610-0012');
      expect(invoiceLogs.length, equals(2)); // CREATE_INVOICE and RECORD_PAYMENT

      final domainLogs = AuditRepository.filterLogs(sampleLogs, searchQuery: 'cloud.sukses.id');
      expect(domainLogs.length, equals(1));
      expect(domainLogs.first.action, equals('CREATE_SERVICE'));
    });

    test('Searches by targetId keyword', () {
      final targetLogs = AuditRepository.filterLogs(sampleLogs, searchQuery: 'CUS-021');
      expect(targetLogs.length, equals(1));
      expect(targetLogs.first.targetId, equals('CUS-021'));
    });

    test('Combined category and search filtering', () {
      final combined = AuditRepository.filterLogs(
        sampleLogs,
        categoryFilter: 'FINANCE',
        searchQuery: 'Transfer Bank',
      );
      expect(combined.length, equals(1));
      expect(combined.first.action, equals('RECORD_PAYMENT'));
    });

    test('Logs are sorted chronologically descending (newest first)', () {
      final sorted = AuditRepository.filterLogs(sampleLogs);
      expect(sorted.first.id, equals('5')); // 14:00
      expect(sorted.last.id, equals('1'));  // 10:00
    });
  });
}
