import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_log_model.dart';

class AuditRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _logsRef => _firestore.collection('activity_logs');

  Stream<List<ActivityLogModel>> watchLogs({String? categoryFilter}) {
    return _logsRef.snapshots().map((snap) {
      var list = snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
      if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'all') {
        list = list.where((l) => l.category.toLowerCase() == categoryFilter.toLowerCase()).toList();
      }
      list.sort((a, b) {
        final aDate = a.timestamp ?? DateTime(2000);
        final bDate = b.timestamp ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return list.take(100).toList();
    });
  }

  Future<List<ActivityLogModel>> getLogs({String? categoryFilter, int limit = 100}) async {
    final snap = await _logsRef.limit(200).get();
    var list = snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'all') {
      list = list.where((l) => l.category.toLowerCase() == categoryFilter.toLowerCase()).toList();
    }
    list.sort((a, b) {
      final aDate = a.timestamp ?? DateTime(2000);
      final bDate = b.timestamp ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return list.take(limit).toList();
  }
}
