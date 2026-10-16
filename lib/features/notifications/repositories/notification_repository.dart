import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _notifRef => _firestore.collection('notifications');

  Stream<List<AppNotificationModel>> watchNotifications() {
    return _notifRef.orderBy('createdAt', descending: true).limit(50).snapshots().map((snap) {
      return snap.docs.map((d) => AppNotificationModel.fromFirestore(d)).toList();
    });
  }

  Stream<int> watchUnreadCount() {
    return _notifRef.where('isRead', isEqualTo: false).snapshots().map((snap) => snap.docs.length);
  }

  Future<void> markAsRead(String id) async {
    await _notifRef.doc(id).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead() async {
    final snap = await _notifRef.where('isRead', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
