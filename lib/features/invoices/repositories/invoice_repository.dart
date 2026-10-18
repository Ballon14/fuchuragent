import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invoice_model.dart';
import '../../payments/models/payment_model.dart';
import '../../../core/constants/app_constants.dart';

class InvoiceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _invoicesRef => _firestore.collection('invoices');

  Stream<List<InvoiceModel>> watchInvoices({String? statusFilter}) {
    return _invoicesRef.snapshots().map((snap) {
      var list = snap.docs.map((d) => InvoiceModel.fromFirestore(d)).toList();
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        list = list.where((inv) => inv.status.toLowerCase() == statusFilter.toLowerCase()).toList();
      }
      list.sort((a, b) {
        final aDate = a.dueDate ?? DateTime(2000);
        final bDate = b.dueDate ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return list;
    });
  }

  Future<List<InvoiceModel>> getInvoices({
    String? searchQuery,
    String? statusFilter,
    int limit = 50,
  }) async {
    final snap = await _invoicesRef.limit(200).get();
    var list = snap.docs.map((d) => InvoiceModel.fromFirestore(d)).toList();

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      list = list.where((inv) => inv.status.toLowerCase() == statusFilter.toLowerCase()).toList();
    }

    list.sort((a, b) {
      final aDate = a.dueDate ?? DateTime(2000);
      final bDate = b.dueDate ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((inv) {
        return inv.invoiceNumber.toLowerCase().contains(q) ||
            inv.notes.toLowerCase().contains(q);
      }).toList();
    }

    return list.take(limit).toList();
  }

  Future<InvoiceModel?> getInvoiceById(String id) async {
    final doc = await _invoicesRef.doc(id).get();
    if (!doc.exists) return null;
    return InvoiceModel.fromFirestore(doc);
  }

  Future<InvoiceModel> createInvoice({
    required String customerId,
    String? serviceId,
    required List<InvoiceItem> items,
    int discount = 0,
    DateTime? dueDate,
    String notes = '',
  }) async {
    try {
      // 1. Preferred server-side execution via Cloud Function callable
      final callable = _functions.httpsCallable('createInvoice');
      final result = await callable.call({
        'customerId': customerId,
        'serviceId': serviceId,
        'items': items.map((e) => e.toMap()).toList(),
        'discount': discount,
        'dueDate': dueDate?.toIso8601String(),
        'notes': notes,
      });

      final invoiceData = result.data['invoice'] as Map<String, dynamic>;
      final docSnap = await _invoicesRef.doc(invoiceData['id'] as String).get();

      // Buat Notifikasi Sistem untuk Administrator & Staff
      try {
        final totalAmount = (invoiceData['total'] as num?)?.toInt() ?? 0;
        await _firestore.collection('notifications').add({
          'title': 'Tagihan Baru Diterbitkan',
          'message': 'Tagihan ${invoiceData['invoiceNumber']} diterbitkan senilai ${AppConstants.formatRupiah(totalAmount)}.',
          'category': 'INVOICE',
          'invoiceId': invoiceData['id'],
          'customerId': customerId,
          'serviceId': serviceId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      return InvoiceModel.fromFirestore(docSnap);
    } catch (_) {
      // 2. Atomic fallback transaction for local emulator or when functions are pending deploy
      return await _firestore.runTransaction((transaction) async {
        int subtotal = 0;
        for (final item in items) {
          subtotal += item.unitPrice * item.quantity;
        }
        final total = (subtotal - discount).clamp(0, double.infinity).toInt();

        final now = DateTime.now();
        final yearMonth = '${now.year}${now.month.toString().padLeft(2, '0')}';
        final counterRef = _firestore.collection('app_settings').doc('invoice_counter');
        final counterSnap = await transaction.get(counterRef);

        int nextNum = 1;
        if (counterSnap.exists && counterSnap.data()?[yearMonth] != null) {
          nextNum = (counterSnap.data()![yearMonth] as num).toInt() + 1;
        }
        transaction.set(counterRef, {yearMonth: nextNum}, SetOptions(merge: true));

        final invoiceNumber = 'INV-$yearMonth-${nextNum.toString().padLeft(4, '0')}';
        final docRef = _invoicesRef.doc();

        final invoice = InvoiceModel(
          id: docRef.id,
          invoiceNumber: invoiceNumber,
          customerId: customerId,
          serviceId: serviceId,
          items: items,
          subtotal: subtotal,
          discount: discount,
          total: total,
          paidAmount: 0,
          status: 'unpaid',
          issuedAt: now,
          dueDate: dueDate ?? now.add(const Duration(days: 7)),
          notes: notes,
          createdBy: _auth.currentUser?.uid,
          createdAt: now,
          updatedAt: now,
        );

        transaction.set(docRef, invoice.toMap());

        // Log audit
        final logRef = _firestore.collection('activity_logs').doc();
        transaction.set(logRef, {
          'actorId': _auth.currentUser?.uid ?? 'system',
          'actorName': _auth.currentUser?.email ?? 'Admin',
          'action': 'CREATE_INVOICE',
          'category': 'FINANCE',
          'details': 'Tagihan $invoiceNumber dibuat sejumlah Rp$total',
          'targetId': docRef.id,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Buat Notifikasi Sistem untuk Administrator & Staff
        final notifRef = _firestore.collection('notifications').doc();
        transaction.set(notifRef, {
          'title': 'Tagihan Baru Diterbitkan',
          'message': 'Tagihan $invoiceNumber diterbitkan senilai ${AppConstants.formatRupiah(total)}.',
          'category': 'INVOICE',
          'invoiceId': docRef.id,
          'customerId': customerId,
          'serviceId': serviceId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return invoice;
      });
    }
  }

  Future<void> cancelInvoice(String invoiceId, String reason) async {
    await _invoicesRef.doc(invoiceId).update({
      'status': 'cancelled',
      'notes': FieldValue.arrayUnion(['Dibatalkan: $reason']),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'CANCEL_INVOICE',
      'category': 'FINANCE',
      'details': 'Membatalkan tagihan ID: $invoiceId. Alasan: $reason',
      'targetId': invoiceId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<PaymentModel>> watchInvoicePayments(String invoiceId) {
    return _firestore
        .collection('payments')
        .where('invoiceId', isEqualTo: invoiceId)
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => PaymentModel.fromFirestore(d)).toList());
  }
}
