import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/notifications/models/notification_model.dart';

void main() {
  group('Notification Model Tests', () {
    test('AppNotificationModel fromMap and toMap round-trip', () {
      final now = DateTime(2026, 10, 18, 10, 30);
      final model = AppNotificationModel(
        id: 'notif-123',
        title: 'Peringatan Jatuh Tempo VPS',
        message: 'Layanan vps1.example.com akan kedaluwarsa 3 hari lagi.',
        category: 'EXPIRATION',
        serviceId: 'srv-001',
        customerId: 'cus-001',
        invoiceId: 'inv-001',
        isRead: false,
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['title'], equals('Peringatan Jatuh Tempo VPS'));
      expect(map['category'], equals('EXPIRATION'));
      expect(map['serviceId'], equals('srv-001'));
      expect(map['customerId'], equals('cus-001'));
      expect(map['invoiceId'], equals('inv-001'));
      expect(map['isRead'], equals(false));

      final restored = AppNotificationModel.fromMap('notif-123', {
        'title': map['title'],
        'message': map['message'],
        'category': map['category'],
        'serviceId': map['serviceId'],
        'customerId': map['customerId'],
        'invoiceId': map['invoiceId'],
        'isRead': map['isRead'],
        'createdAt': now,
      });

      expect(restored.id, equals('notif-123'));
      expect(restored.title, equals(model.title));
      expect(restored.category, equals('EXPIRATION'));
      expect(restored.serviceId, equals('srv-001'));
      expect(restored.invoiceId, equals('inv-001'));
      expect(restored.isRead, isFalse);
    });

    test('AppNotificationModel copyWith updates fields correctly', () {
      final model = AppNotificationModel(
        id: 'notif-456',
        title: 'Tagihan Baru',
        message: 'Tagihan INV-001 diterbitkan',
        category: 'INVOICE',
        isRead: false,
      );

      final updated = model.copyWith(isRead: true);
      expect(updated.id, equals('notif-456'));
      expect(updated.isRead, isTrue);
      expect(updated.title, equals('Tagihan Baru'));
    });
  });

  group('Notification Filtering and Categorization Tests', () {
    final notifications = [
      AppNotificationModel(
        id: '1',
        title: 'VPS Expiring',
        message: 'vps1 expiring soon',
        category: 'EXPIRATION',
        serviceId: 'srv-1',
        isRead: false,
      ),
      AppNotificationModel(
        id: '2',
        title: 'Invoice Overdue',
        message: 'inv-1 is overdue',
        category: 'INVOICE',
        invoiceId: 'inv-1',
        isRead: true,
      ),
      AppNotificationModel(
        id: '3',
        title: 'Payment Received',
        message: 'Payment received for inv-2',
        category: 'PAYMENT',
        invoiceId: 'inv-2',
        isRead: false,
      ),
      AppNotificationModel(
        id: '4',
        title: 'New Customer',
        message: 'Budi registered',
        category: 'SYSTEM',
        customerId: 'cus-1',
        isRead: true,
      ),
    ];

    test('Filter by UNREAD only', () {
      final unread = notifications.where((n) => !n.isRead).toList();
      expect(unread.length, equals(2));
      expect(unread.map((n) => n.id), containsAll(['1', '3']));
    });

    test('Filter by EXPIRATION category', () {
      final expiration = notifications.where((n) => n.category == 'EXPIRATION').toList();
      expect(expiration.length, equals(1));
      expect(expiration.first.id, equals('1'));
    });

    test('Filter by FINANCE category (INVOICE + PAYMENT)', () {
      final finance = notifications.where((n) => n.category == 'INVOICE' || n.category == 'PAYMENT').toList();
      expect(finance.length, equals(2));
      expect(finance.map((n) => n.id), containsAll(['2', '3']));
    });

    test('Filter by SYSTEM category', () {
      final system = notifications.where((n) => n.category == 'SYSTEM').toList();
      expect(system.length, equals(1));
      expect(system.first.id, equals('4'));
    });
  });

  group('System Alert Deduction and Deduplication Logic Tests', () {
    test('Deduplication logic skips services with existing active alerts within 24h', () {
      final now = DateTime(2026, 10, 18, 12, 0);
      final dayAgo = now.subtract(const Duration(hours: 24));

      final existingAlerts = [
        AppNotificationModel(
          id: 'old-1',
          title: 'Kedaluwarsa VPS',
          message: 'Layanan vps1',
          category: 'EXPIRATION',
          serviceId: 'srv-101',
          isRead: false, // Unread alert exists
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        AppNotificationModel(
          id: 'old-2',
          title: 'Tagihan Jatuh Tempo',
          message: 'Tagihan INV-01',
          category: 'INVOICE',
          invoiceId: 'inv-201',
          isRead: true, // Read, but created 5 hours ago (< 24h)
          createdAt: now.subtract(const Duration(hours: 5)),
        ),
        AppNotificationModel(
          id: 'old-3',
          title: 'Old Notification',
          message: 'Old alert',
          category: 'EXPIRATION',
          serviceId: 'srv-999',
          isRead: true, // Read, created 48 hours ago (> 24h)
          createdAt: now.subtract(const Duration(hours: 48)),
        ),
      ];

      final activeServiceAlerts = <String>{};
      final activeInvoiceAlerts = <String>{};

      for (final n in existingAlerts) {
        final isRecent = n.createdAt != null && n.createdAt!.isAfter(dayAgo);
        if (!n.isRead || isRecent) {
          if (n.category == 'EXPIRATION' && n.serviceId != null) {
            activeServiceAlerts.add(n.serviceId!);
          }
          if (n.category == 'INVOICE' && n.invoiceId != null) {
            activeInvoiceAlerts.add(n.invoiceId!);
          }
        }
      }

      // 'srv-101' is active because it's unread and recent
      expect(activeServiceAlerts.contains('srv-101'), isTrue);

      // 'inv-201' is active because it was created <24h ago
      expect(activeInvoiceAlerts.contains('inv-201'), isTrue);

      // 'srv-999' is NOT active because it was read and older than 24h
      expect(activeServiceAlerts.contains('srv-999'), isFalse);
    });

    test('Expiring detection within 7 days threshold', () {
      final now = DateTime(2026, 10, 18);
      final service1End = now.add(const Duration(days: 3));
      final service2End = now.add(const Duration(days: 14));
      final service3End = now.subtract(const Duration(days: 1)); // Expired

      // Service 1: 3 days left -> should alert
      expect(service1End.difference(now).inDays <= 7, isTrue);

      // Service 2: 14 days left -> should NOT alert yet
      expect(service2End.difference(now).inDays <= 7, isFalse);

      // Service 3: already expired -> should alert as expired
      expect(service3End.isBefore(now), isTrue);
    });

    test('Overdue invoice detection', () {
      final now = DateTime(2026, 10, 18);
      final duePast = now.subtract(const Duration(days: 2));
      final dueFuture = now.add(const Duration(days: 5));

      expect(duePast.isBefore(now), isTrue);
      expect(dueFuture.isBefore(now), isFalse);
    });
  });
}
