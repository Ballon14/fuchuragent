import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _paymentsRef => _firestore.collection('payments');

  Stream<List<PaymentModel>> watchPayments() {
    return _paymentsRef
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PaymentModel.fromFirestore(d)).toList());
  }

  Future<List<PaymentModel>> getPayments({int limit = 50}) async {
    final snap = await _paymentsRef
        .orderBy('paymentDate', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => PaymentModel.fromFirestore(d)).toList();
  }

  Future<PaymentModel> recordPayment({
    required String invoiceId,
    required int amount,
    required String paymentMethod,
    String referenceNumber = '',
    String notes = '',
    String? receiptUrl,
  }) async {
    final idempotencyKey = const Uuid().v4();

    try {
      // 1. Preferred server-side execution via Cloud Function callable
      final callable = _functions.httpsCallable('recordPayment');
      final result = await callable.call({
        'invoiceId': invoiceId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'referenceNumber': referenceNumber,
        'notes': notes,
        'idempotencyKey': idempotencyKey,
      });

      final paymentData = result.data['payment'] as Map<String, dynamic>;
      final docSnap = await _paymentsRef.doc(paymentData['id'] as String).get();
      return PaymentModel.fromFirestore(docSnap);
    } catch (_) {
      // 2. Atomic fallback transaction ensuring financial consistency
      return await _firestore.runTransaction((transaction) async {
        final invoiceRef = _firestore.collection('invoices').doc(invoiceId);
        final invoiceSnap = await transaction.get(invoiceRef);

        if (!invoiceSnap.exists) {
          throw Exception('Tagihan tidak ditemukan.');
        }

        final inv = invoiceSnap.data()!;
        final currentPaid = (inv['paidAmount'] as num?)?.toInt() ?? 0;
        final total = (inv['total'] as num?)?.toInt() ?? 0;

        final newPaid = currentPaid + amount;
        final newStatus = newPaid >= total ? 'paid' : 'partial';

        final paymentRef = _paymentsRef.doc();
        final now = DateTime.now();

        final payment = PaymentModel(
          id: paymentRef.id,
          invoiceId: invoiceId,
          customerId: inv['customerId'] as String? ?? '',
          serviceId: inv['serviceId'] as String?,
          amount: amount,
          paymentDate: now,
          paymentMethod: paymentMethod,
          referenceNumber: referenceNumber,
          receiptUrl: receiptUrl,
          recordedBy: _auth.currentUser?.uid,
          notes: notes,
          idempotencyKey: idempotencyKey,
          createdAt: now,
        );

        transaction.set(paymentRef, payment.toMap());
        transaction.update(invoiceRef, {
          'paidAmount': newPaid,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Audit Log
        final logRef = _firestore.collection('activity_logs').doc();
        transaction.set(logRef, {
          'actorId': _auth.currentUser?.uid ?? 'system',
          'actorName': _auth.currentUser?.email ?? 'Admin',
          'action': 'RECORD_PAYMENT',
          'category': 'FINANCE',
          'details': 'Pembayaran Rp$amount dicatat untuk tagihan ${inv['invoiceNumber']} ($paymentMethod). Status: $newStatus',
          'targetId': paymentRef.id,
          'timestamp': FieldValue.serverTimestamp(),
        });

        return payment;
      });
    }
  }

  Future<void> reversePayment({
    required String paymentId,
    required String reason,
  }) async {
    try {
      final callable = _functions.httpsCallable('reversePayment');
      await callable.call({
        'paymentId': paymentId,
        'reason': reason,
      });
    } catch (_) {
      // Fallback transaction
      await _firestore.runTransaction((transaction) async {
        final paymentRef = _paymentsRef.doc(paymentId);
        final paymentSnap = await transaction.get(paymentRef);
        if (!paymentSnap.exists) throw Exception('Data pembayaran tidak ditemukan.');

        final pay = paymentSnap.data() as Map<String, dynamic>;
        if (pay['isReversed'] == true) {
          throw Exception('Pembayaran ini sudah pernah dibatalkan sebelumnya.');
        }

        final invoiceRef = _firestore.collection('invoices').doc(pay['invoiceId'] as String);
        final invoiceSnap = await transaction.get(invoiceRef);
        if (!invoiceSnap.exists) throw Exception('Tagihan terkait tidak ditemukan.');

        final inv = invoiceSnap.data() as Map<String, dynamic>;
        final currentPaid = (inv['paidAmount'] as num?)?.toInt() ?? 0;
        final total = (inv['total'] as num?)?.toInt() ?? 0;
        final payAmount = (pay['amount'] as num?)?.toInt() ?? 0;

        final newPaid = (currentPaid - payAmount).clamp(0, double.infinity).toInt();
        String newStatus = 'unpaid';
        if (newPaid >= total && total > 0) {
          newStatus = 'paid';
        } else if (newPaid > 0) {
          newStatus = 'partial';
        }

        transaction.update(paymentRef, {
          'isReversed': true,
          'reverseReason': reason,
          'reversedAt': FieldValue.serverTimestamp(),
          'reversedBy': _auth.currentUser?.uid,
        });

        transaction.update(invoiceRef, {
          'paidAmount': newPaid,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final logRef = _firestore.collection('activity_logs').doc();
        transaction.set(logRef, {
          'actorId': _auth.currentUser?.uid ?? 'system',
          'actorName': _auth.currentUser?.email ?? 'Admin',
          'action': 'REVERSE_PAYMENT',
          'category': 'FINANCE',
          'details': 'Koreksi/Pembatalan pembayaran Rp$payAmount. Alasan: $reason',
          'targetId': paymentId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    }
  }
}
