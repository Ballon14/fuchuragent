import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/renewal_model.dart';

class RenewalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _renewalsRef => _firestore.collection('service_renewals');

  Stream<List<ServiceRenewalModel>> watchRenewals() {
    return _renewalsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ServiceRenewalModel.fromFirestore(d)).toList());
  }

  Future<ServiceRenewalModel> renewService({
    required String serviceId,
    required int durationMonths,
    String? invoiceId,
    String notes = '',
  }) async {
    final idempotencyKey = const Uuid().v4();

    try {
      // 1. Preferred server-side execution via Cloud Function callable
      final callable = _functions.httpsCallable('renewService');
      final result = await callable.call({
        'serviceId': serviceId,
        'durationMonths': durationMonths,
        'invoiceId': invoiceId,
        'idempotencyKey': idempotencyKey,
        'notes': notes,
      });

      final renewalData = result.data['renewal'] as Map<String, dynamic>;
      final docSnap = await _renewalsRef.doc(renewalData['id'] as String).get();
      return ServiceRenewalModel.fromFirestore(docSnap);
    } catch (_) {
      // 2. Atomic fallback transaction preventing double renewals and concurrency collisions
      return await _firestore.runTransaction((transaction) async {
        final serviceRef = _firestore.collection('vps_services').doc(serviceId);
        final serviceSnap = await transaction.get(serviceRef);

        if (!serviceSnap.exists) {
          throw Exception('Layanan VPS tidak ditemukan.');
        }

        final svc = serviceSnap.data()!;
        final oldEndTimestamp = svc['endDate'] as Timestamp?;
        final oldEndDate = oldEndTimestamp?.toDate() ?? DateTime.now();
        final now = DateTime.now();

        // If old end date is still in the future, extend from that end date; otherwise from today
        final baseDate = oldEndDate.isAfter(now) ? oldEndDate : now;
        final newEndDate = DateTime(
          baseDate.year,
          baseDate.month + durationMonths,
          baseDate.day,
          baseDate.hour,
          baseDate.minute,
        );

        final renewalRef = _renewalsRef.doc();
        final renewal = ServiceRenewalModel(
          id: renewalRef.id,
          serviceId: serviceId,
          customerId: svc['customerId'] as String? ?? '',
          previousEndDate: oldEndDate,
          newEndDate: newEndDate,
          durationMonths: durationMonths,
          invoiceId: invoiceId,
          adminId: _auth.currentUser?.uid,
          notes: notes,
          idempotencyKey: idempotencyKey,
          createdAt: now,
        );

        transaction.set(renewalRef, renewal.toMap());
        transaction.update(serviceRef, {
          'endDate': Timestamp.fromDate(newEndDate),
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Audit log
        final logRef = _firestore.collection('activity_logs').doc();
        transaction.set(logRef, {
          'actorId': _auth.currentUser?.uid ?? 'system',
          'actorName': _auth.currentUser?.email ?? 'Admin',
          'action': 'RENEW_SERVICE',
          'category': 'SERVICES',
          'details': 'Perpanjangan layanan VPS ${svc['domain']} (+$durationMonths bulan) s.d ${newEndDate.day}/${newEndDate.month}/${newEndDate.year}',
          'targetId': renewalRef.id,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return renewal;
      });
    }
  }
}
