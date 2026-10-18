import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../models/notification_model.dart';
import '../services/local_notification_service.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _notifRef => _firestore.collection('notifications');

  Stream<List<AppNotificationModel>> watchNotifications({
    String? categoryFilter,
    bool unreadOnly = false,
  }) {
    return _notifRef
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      var list = snap.docs.map((d) => AppNotificationModel.fromFirestore(d)).toList();

      if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'ALL') {
        list = list.where((n) => n.category.toUpperCase() == categoryFilter.toUpperCase()).toList();
      }

      if (unreadOnly) {
        list = list.where((n) => !n.isRead).toList();
      }

      return list;
    });
  }

  Stream<int> watchUnreadCount() {
    return _notifRef
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<String> createNotification({
    required String title,
    required String message,
    required String category, // 'EXPIRATION', 'PAYMENT', 'INVOICE', 'SYSTEM'
    String? serviceId,
    String? customerId,
    String? invoiceId,
  }) async {
    final docRef = await _notifRef.add({
      'title': title,
      'message': message,
      'category': category.toUpperCase(),
      'serviceId': serviceId,
      'customerId': customerId,
      'invoiceId': invoiceId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      final notifId = docRef.id.hashCode.abs() % 1000000;
      String? channelId;
      final cat = category.toUpperCase();
      if (cat == 'PAYMENT' || cat == 'INVOICE' || cat == 'EXPENSE') {
        channelId = LocalNotificationService.financialChannelId;
      } else if (cat == 'SYSTEM' || cat == 'BACKUP') {
        channelId = LocalNotificationService.systemChannelId;
      } else {
        channelId = LocalNotificationService.channelId;
      }

      await LocalNotificationService().showNotification(
        id: notifId,
        title: title,
        body: message,
        payload: '/notifications',
        targetChannelId: channelId,
      );
    } catch (_) {}

    return docRef.id;
  }

  Future<void> markAsRead(String id) async {
    await _notifRef.doc(id).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead() async {
    final snap = await _notifRef.where('isRead', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String id) async {
    await _notifRef.doc(id).delete();
  }

  Future<void> clearReadNotifications() async {
    final snap = await _notifRef.where('isRead', isEqualTo: true).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Sinkronisasi otomatis notifikasi sistem untuk Administrator & Staff:
  /// 1. Layanan VPS yang mendekati kedaluwarsa (<= 7 hari) dan telah kedaluwarsa.
  /// 2. Tagihan yang telah melewati jatuh tempo (Overdue) dan belum lunas.
  /// Menerapkan anti-spam deduplikasi agar tidak membombardir notifikasi yang sama dalam 24 jam.
  Future<int> syncSystemAlerts() async {
    int createdCount = 0;
    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(hours: 24));

    try {
      // 1. Ambil 100 notifikasi terbaru untuk memeriksa riwayat deduplikasi
      final recentSnap = await _notifRef
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final recentDocs = recentSnap.docs.map((d) => AppNotificationModel.fromFirestore(d)).toList();

      final activeServiceAlerts = <String>{};
      final activeInvoiceAlerts = <String>{};

      for (final n in recentDocs) {
        final isRecent = n.createdAt != null && n.createdAt!.isAfter(dayAgo);
        // Jika belum dibaca atau dibuat dalam 24 jam terakhir, hindari duplikasi
        if (!n.isRead || isRecent) {
          if (n.category == 'EXPIRATION' && n.serviceId != null) {
            activeServiceAlerts.add(n.serviceId!);
          }
          if (n.category == 'INVOICE' && n.invoiceId != null) {
            activeInvoiceAlerts.add(n.invoiceId!);
          }
        }
      }

      // 2. Periksa Layanan VPS Aktif yang mendekati atau telah kedaluwarsa
      final vpsSnap = await _firestore.collection('vps_services').get();
      for (final doc in vpsSnap.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').toLowerCase();
        // Hanya cek layanan aktif
        if (status != 'active' && status != 'actice') continue;

        final endDate = AppConstants.parseDateTime(data['endDate']);
        if (endDate == null) continue;

        final domain = data['domain'] as String? ?? 'VPS';
        final packageName = data['packageName'] as String? ?? '';
        final custId = data['customerId'] as String?;

        if (activeServiceAlerts.contains(doc.id)) continue;

        if (endDate.isBefore(now)) {
          // Layanan sudah kedaluwarsa
          await createNotification(
            title: 'Layanan VPS Kedaluwarsa',
            message: 'Layanan $domain ($packageName) telah kedaluwarsa pada ${AppConstants.formatDate(endDate)}. Harap hubungi pelanggan untuk proses perpanjangan atau suspend.',
            category: 'EXPIRATION',
            serviceId: doc.id,
            customerId: custId,
          );
          activeServiceAlerts.add(doc.id);
          createdCount++;
        } else {
          final diff = endDate.difference(now);
          if (diff.inDays <= 7) {
            final daysLeft = diff.inDays == 0 ? 'hari ini' : '${diff.inDays} hari lagi';
            await createNotification(
              title: 'Peringatan Jatuh Tempo VPS',
              message: 'Layanan $domain ($packageName) akan kedaluwarsa $daysLeft (${AppConstants.formatDate(endDate)}).',
              category: 'EXPIRATION',
              serviceId: doc.id,
              customerId: custId,
            );
            activeServiceAlerts.add(doc.id);
            createdCount++;
          }
        }
      }

      // 3. Periksa Tagihan yang Belum Lunas dan Jatuh Tempo
      final invSnap = await _firestore.collection('invoices').get();
      for (final doc in invSnap.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').toLowerCase();
        if (status != 'unpaid' && status != 'partial') continue;

        final dueDate = AppConstants.parseDateTime(data['dueDate']);
        if (dueDate == null) continue;

        final invNumber = data['invoiceNumber'] as String? ?? 'Tagihan';
        final total = (data['total'] as num?)?.toInt() ?? 0;
        final paid = (data['paidAmount'] as num?)?.toInt() ?? 0;
        final remaining = (total - paid).clamp(0, total);
        final custId = data['customerId'] as String?;
        final servId = data['serviceId'] as String?;

        if (activeInvoiceAlerts.contains(doc.id)) continue;

        if (dueDate.isBefore(now)) {
          final daysOverdue = now.difference(dueDate).inDays;
          final overdueText = daysOverdue <= 0 ? 'hari ini' : '$daysOverdue hari lalu';
          await createNotification(
            title: 'Tagihan Jatuh Tempo (Belum Lunas)',
            message: 'Tagihan $invNumber dengan sisa ${AppConstants.formatRupiah(remaining)} telah jatuh tempo $overdueText (${AppConstants.formatDate(dueDate)}).',
            category: 'INVOICE',
            invoiceId: doc.id,
            serviceId: servId,
            customerId: custId,
          );
          activeInvoiceAlerts.add(doc.id);
          createdCount++;
        }
      }
    } catch (_) {
      // Menjaga toleransi kesalahan saat offline / permission error
    }

    return createdCount;
  }
}
