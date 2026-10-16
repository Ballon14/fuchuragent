import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_log_model.dart';

class AuditRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _logsRef => _firestore.collection('activity_logs');

  Stream<List<ActivityLogModel>> watchLogs({String? categoryFilter}) {
    Query query = _logsRef;
    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'all') {
      query = query.where('category', isEqualTo: categoryFilter);
    }
    return query.orderBy('timestamp', descending: true).limit(100).snapshots().map((snap) {
      return snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
    });
  }

  Future<List<ActivityLogModel>> getLogs({String? categoryFilter, int limit = 100}) async {
    Query query = _logsRef;
    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'all') {
      query = query.where('category', isEqualTo: categoryFilter);
    }
    final snap = await query.orderBy('timestamp', descending: true).limit(limit).get();
    return snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
  }
}
