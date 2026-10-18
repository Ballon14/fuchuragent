import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_log_model.dart';

class AuditRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AuditRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference get _logsRef => _firestore.collection('activity_logs');

  /// Mencatat riwayat aktivitas secara terstandarisasi ke audit log
  Future<String> logActivity({
    required String action,
    required String category, // 'FINANCE', 'SERVICES', 'CUSTOMERS', 'SECURITY', 'PACKAGES', 'IMPORT'
    required String details,
    String? targetId,
    String? actorId,
    String? actorName,
  }) async {
    final effectiveActorId = actorId ?? _auth.currentUser?.uid ?? 'system';
    final effectiveActorName = actorName ??
        _auth.currentUser?.displayName ??
        _auth.currentUser?.email ??
        'Admin';

    final docRef = await _logsRef.add({
      'actorId': effectiveActorId,
      'actorName': effectiveActorName,
      'action': action.toUpperCase(),
      'category': category.toUpperCase(),
      'details': details,
      'targetId': targetId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Memantau aliran audit log dengan opsi filter kategori dan pencarian kata kunci
  Stream<List<ActivityLogModel>> watchLogs({
    String? categoryFilter,
    String? searchQuery,
    int limit = 150,
  }) {
    return _logsRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
      return filterLogs(list, categoryFilter: categoryFilter, searchQuery: searchQuery);
    });
  }

  /// Mengambil daftar log audit secara asynchronous
  Future<List<ActivityLogModel>> getLogs({
    String? categoryFilter,
    String? searchQuery,
    int limit = 150,
  }) async {
    final snap = await _logsRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    final list = snap.docs.map((d) => ActivityLogModel.fromFirestore(d)).toList();
    return filterLogs(list, categoryFilter: categoryFilter, searchQuery: searchQuery);
  }

  /// Logika penyaringan log aktivitas (dapat diuji secara murni di unit test)
  static List<ActivityLogModel> filterLogs(
    List<ActivityLogModel> logs, {
    String? categoryFilter,
    String? searchQuery,
  }) {
    var result = List<ActivityLogModel>.from(logs);

    if (categoryFilter != null &&
        categoryFilter.isNotEmpty &&
        categoryFilter.toLowerCase() != 'all') {
      result = result
          .where((l) => l.category.toUpperCase() == categoryFilter.toUpperCase())
          .toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((l) {
        return l.details.toLowerCase().contains(q) ||
            l.action.toLowerCase().contains(q) ||
            l.actorName.toLowerCase().contains(q) ||
            (l.targetId?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    result.sort((a, b) {
      final aDate = a.timestamp ?? DateTime(2000);
      final bDate = b.timestamp ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return result;
  }
}
