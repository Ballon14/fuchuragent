import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_model.dart';

class ServiceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _servicesRef => _firestore.collection('vps_services');

  Stream<List<VpsServiceModel>> watchServices({String? statusFilter}) {
    return _servicesRef.snapshots().map((snap) {
      var list = snap.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        if (statusFilter == 'active') {
          list = list.where((s) => s.status.toLowerCase() == 'active' || s.status.toLowerCase() == 'actice').toList();
        } else {
          list = list.where((s) => s.status.toLowerCase() == statusFilter.toLowerCase()).toList();
        }
      }
      list.sort((a, b) {
        final aDate = a.endDate ?? DateTime(2099);
        final bDate = b.endDate ?? DateTime(2099);
        return aDate.compareTo(bDate);
      });
      return list;
    });
  }

  Future<List<VpsServiceModel>> getServices({
    String? searchQuery,
    String? statusFilter,
    int limit = 100,
  }) async {
    final snap = await _servicesRef.limit(200).get();
    var list = snap.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      if (statusFilter == 'active') {
        list = list.where((s) => s.status.toLowerCase() == 'active' || s.status.toLowerCase() == 'actice').toList();
      } else {
        list = list.where((s) => s.status.toLowerCase() == statusFilter.toLowerCase()).toList();
      }
    }

    list.sort((a, b) {
      final aDate = a.endDate ?? DateTime(2099);
      final bDate = b.endDate ?? DateTime(2099);
      return aDate.compareTo(bDate);
    });

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

    // Buat Notifikasi Sistem untuk Administrator & Staff
    await _firestore.collection('notifications').add({
      'title': 'Layanan VPS Baru Dibuat',
      'message': 'Layanan VPS ${service.domain} (${service.packageName}) telah didaftarkan.',
      'category': 'SYSTEM',
      'serviceId': docRef.id,
      'customerId': service.customerId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
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
