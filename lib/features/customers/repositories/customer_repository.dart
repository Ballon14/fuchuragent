import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer_model.dart';
import '../../services/models/service_model.dart';
import '../../invoices/models/invoice_model.dart';
import '../../payments/models/payment_model.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _customersRef => _firestore.collection('customers');

  Stream<List<CustomerModel>> watchCustomers({String? statusFilter}) {
    return _customersRef.snapshots().map((snap) {
      var list = snap.docs.map((d) => CustomerModel.fromFirestore(d)).toList();
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        list = list.where((c) => c.status.toLowerCase() == statusFilter.toLowerCase()).toList();
      }
      list.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return list;
    });
  }

  Future<List<CustomerModel>> getCustomers({
    String? searchQuery,
    String? statusFilter,
    int limit = 50,
  }) async {
    final snap = await _customersRef.limit(200).get();
    var list = snap.docs.map((d) => CustomerModel.fromFirestore(d)).toList();

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      list = list.where((c) => c.status.toLowerCase() == statusFilter.toLowerCase()).toList();
    }

    list.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(2000);
      final bDate = b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            c.sourceId.toLowerCase().contains(q) ||
            (c.email?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return list.take(limit).toList();
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    final doc = await _customersRef.doc(id).get();
    if (!doc.exists) return null;
    return CustomerModel.fromFirestore(doc);
  }

  Future<String> addCustomer(CustomerModel customer) async {
    final docRef = _customersRef.doc(customer.id.isNotEmpty ? customer.id : null);
    await docRef.set(customer.toMap());

    // Log Activity
    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'CREATE_CUSTOMER',
      'category': 'CUSTOMERS',
      'details': 'Menambahkan pelanggan baru: ${customer.name} (${customer.phone})',
      'targetId': docRef.id,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _customersRef.doc(customer.id).update(customer.toMap());

    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'UPDATE_CUSTOMER',
      'category': 'CUSTOMERS',
      'details': 'Memperbarui data pelanggan: ${customer.name}',
      'targetId': customer.id,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveCustomer(String customerId) async {
    await _customersRef.doc(customerId).update({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'ARCHIVE_CUSTOMER',
      'category': 'CUSTOMERS',
      'details': 'Mengarsipkan pelanggan ID: $customerId',
      'targetId': customerId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCustomer(String customerId) async {
    // Safety check: Prevent deletion if customer has active VPS services or invoices
    final servicesSnap = await _firestore
        .collection('vps_services')
        .where('customerId', isEqualTo: customerId)
        .limit(1)
        .get();

    if (servicesSnap.docs.isNotEmpty) {
      throw Exception('Tidak dapat menghapus pelanggan yang memiliki riwayat layanan VPS. Gunakan fitur Arsip.');
    }

    final invoicesSnap = await _firestore
        .collection('invoices')
        .where('customerId', isEqualTo: customerId)
        .limit(1)
        .get();

    if (invoicesSnap.docs.isNotEmpty) {
      throw Exception('Tidak dapat menghapus pelanggan yang memiliki riwayat tagihan. Gunakan fitur Arsip.');
    }

    await _customersRef.doc(customerId).delete();

    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'DELETE_CUSTOMER',
      'category': 'CUSTOMERS',
      'details': 'Menghapus pelanggan ID: $customerId',
      'targetId': customerId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Relations
  Stream<List<VpsServiceModel>> watchCustomerServices(String customerId) {
    return _firestore
        .collection('vps_services')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();
          list.sort((a, b) {
            final aDate = a.createdAt ?? DateTime(2000);
            final bDate = b.createdAt ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
          return list;
        });
  }

  Stream<List<InvoiceModel>> watchCustomerInvoices(String customerId) {
    return _firestore
        .collection('invoices')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => InvoiceModel.fromFirestore(d)).toList();
          list.sort((a, b) {
            final aDate = a.dueDate ?? DateTime(2000);
            final bDate = b.dueDate ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
          return list;
        });
  }

  Stream<List<PaymentModel>> watchCustomerPayments(String customerId) {
    return _firestore
        .collection('payments')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => PaymentModel.fromFirestore(d)).toList();
          list.sort((a, b) {
            final aDate = a.paymentDate ?? DateTime(2000);
            final bDate = b.paymentDate ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
          return list;
        });
  }
}
