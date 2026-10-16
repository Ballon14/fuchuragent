import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_model.dart';

class ServiceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _servicesRef => _firestore.collection('vps_services');

  Stream<List<VpsServiceModel>> watchServices({String? statusFilter}) {
    Query query = _servicesRef;
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      if (statusFilter == 'active') {
        // Handle "actice" typo normalization in queries as well
        query = query.where('status', whereIn: ['active', 'actice']);
      } else {
        query = query.where('status', isEqualTo: statusFilter);
      }
    }
    return query.orderBy('endDate', descending: false).snapshots().map((snap) {
      return snap.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();
    });
  }

  Future<List<VpsServiceModel>> getServices({
    String? searchQuery,
    String? statusFilter,
    int limit = 100,
  }) async {
    Query query = _servicesRef;

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      if (statusFilter == 'active') {
        query = query.where('status', whereIn: ['active', 'actice']);
      } else {
        query = query.where('status', isEqualTo: statusFilter);
      }
    }

    final snap = await query.limit(limit).get();
    var list = snap.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((s) {
        return s.domain.toLowerCase().contains(q) ||
            s.serviceName.toLowerCase().contains(q) ||
            s.packageName.toLowerCase().contains(q) ||
            (s.worker?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return list;
  }

  Future<VpsServiceModel?> getServiceById(String id) async {
    final doc = await _servicesRef.doc(id).get();
    if (!doc.exists) return null;
    return VpsServiceModel.fromFirestore(doc);
  }

  Future<String> addService(VpsServiceModel service) async {
    final docRef = _servicesRef.doc(service.id.isNotEmpty ? service.id : null);
    await docRef.set(service.toMap());

    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'CREATE_SERVICE',
      'category': 'SERVICES',
      'details': 'Menambahkan layanan VPS: ${service.domain} (${service.packageName})',
      'targetId': docRef.id,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> updateService(VpsServiceModel service) async {
    await _servicesRef.doc(service.id).update(service.toMap());

    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'UPDATE_SERVICE',
      'category': 'SERVICES',
      'details': 'Memperbarui layanan VPS: ${service.domain}',
      'targetId': service.id,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<VpsServiceModel>> getExpiringServices(int days) async {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: days));

    final snap = await _servicesRef
        .where('status', whereIn: ['active', 'actice'])
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(threshold))
        .orderBy('endDate', descending: false)
        .get();

    return snap.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();
  }

  Future<List<VpsServiceModel>> getExpiredServices() async {
    final now = DateTime.now();
    final snap = await _servicesRef
        .where('endDate', isLessThan: Timestamp.fromDate(now))
        .orderBy('endDate', descending: true)
        .limit(50)
        .get();

    return snap.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();
  }
}
