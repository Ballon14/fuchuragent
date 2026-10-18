import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../models/customer_model.dart';
import '../../services/models/service_model.dart';
import '../../invoices/models/invoice_model.dart';
import '../../payments/models/payment_model.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _customersRef => _firestore.collection('customers');

  /// Memantau data pelanggan secara realtime dengan status dinamis
  /// yang dihitung langsung dari data kelola layanan VPS:
  /// - 'active': memiliki minimal 1 layanan VPS aktif yang belum kedaluwarsa (endDate > now).
  /// - 'inactive': tidak memiliki layanan VPS aktif atau masa aktif telah kedaluwarsa.
  /// - 'archived': pelanggan yang diarsipkan.
  Stream<List<CustomerModel>> watchCustomers({String? statusFilter}) {
    late StreamController<List<CustomerModel>> controller;
    StreamSubscription? custSub;
    StreamSubscription? vpsSub;
    QuerySnapshot? lastCustSnap;
    QuerySnapshot? lastVpsSnap;

    void emitLatest() {
      if (lastCustSnap == null) return;
      final now = DateTime.now();

      final activeCustomerIds = <String>{};
      if (lastVpsSnap != null) {
        for (final doc in lastVpsSnap!.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final status = (data['status'] as String? ?? '').toLowerCase();
          final isStatusActive = status == 'active' || status == 'actice';
          final endDate = AppConstants.parseDateTime(data['endDate']);
          // Layanan aktif dan masa aktif belum kadaluarsa
          if (isStatusActive && endDate != null && endDate.isAfter(now)) {
            final custId = data['customerId'] as String?;
            if (custId != null && custId.isNotEmpty) {
              activeCustomerIds.add(custId);
            }
          }
        }
      }

      var list = lastCustSnap!.docs.map((d) {
        final model = CustomerModel.fromFirestore(d);
        final dynamicStatus = model.isArchived
            ? 'archived'
            : (activeCustomerIds.contains(model.id) ? 'active' : 'inactive');
        return model.copyWith(status: dynamicStatus);
      }).toList();

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        list = list.where((c) => c.status.toLowerCase() == statusFilter.toLowerCase()).toList();
      }

      list.sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    controller = StreamController<List<CustomerModel>>.broadcast(
      onListen: () {
        custSub = _customersRef.snapshots().listen((snap) {
          lastCustSnap = snap;
          emitLatest();
        }, onError: (err) {
          if (!controller.isClosed) controller.addError(err);
        });

        vpsSub = _firestore.collection('vps_services').snapshots().listen((snap) {
          lastVpsSnap = snap;
          emitLatest();
        }, onError: (err) {
          if (!controller.isClosed) controller.addError(err);
        });
      },
      onCancel: () {
        custSub?.cancel();
        vpsSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Memantau satu pelanggan secara spesifik dengan status dinamis realtime
  Stream<CustomerModel?> watchCustomerById(String id) {
    late StreamController<CustomerModel?> controller;
    StreamSubscription? custSub;
    StreamSubscription? vpsSub;
    DocumentSnapshot? lastCustDoc;
    QuerySnapshot? lastVpsSnap;

    void emitLatest() {
      if (lastCustDoc == null || !lastCustDoc!.exists) {
        if (!controller.isClosed) controller.add(null);
        return;
      }
      final now = DateTime.now();
      final model = CustomerModel.fromFirestore(lastCustDoc!);
      bool hasActiveService = false;

      if (lastVpsSnap != null) {
        hasActiveService = lastVpsSnap!.docs.any((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          final status = (data['status'] as String? ?? '').toLowerCase();
          final isStatusActive = status == 'active' || status == 'actice';
          final endDate = AppConstants.parseDateTime(data['endDate']);
          return isStatusActive && endDate != null && endDate.isAfter(now);
        });
      }

      final dynamicStatus = model.isArchived
          ? 'archived'
          : (hasActiveService ? 'active' : 'inactive');

      if (!controller.isClosed) {
        controller.add(model.copyWith(status: dynamicStatus));
      }
    }

    controller = StreamController<CustomerModel?>.broadcast(
      onListen: () {
        custSub = _customersRef.doc(id).snapshots().listen((doc) {
          lastCustDoc = doc;
          emitLatest();
        }, onError: (err) {
          if (!controller.isClosed) controller.addError(err);
        });

        vpsSub = _firestore.collection('vps_services').where('customerId', isEqualTo: id).snapshots().listen((snap) {
          lastVpsSnap = snap;
          emitLatest();
        }, onError: (err) {
          if (!controller.isClosed) controller.addError(err);
        });
      },
      onCancel: () {
        custSub?.cancel();
        vpsSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<List<CustomerModel>> getCustomers({
    String? searchQuery,
    String? statusFilter,
    int limit = 50,
  }) async {
    final snap = await _customersRef.limit(200).get();
    final now = DateTime.now();
    final vpsSnap = await _firestore.collection('vps_services').get();

    final activeCustomerIds = <String>{};
    for (final doc in vpsSnap.docs) {
      final data = doc.data();
      final status = (data['status'] as String? ?? '').toLowerCase();
      final isStatusActive = status == 'active' || status == 'actice';
      final endDate = AppConstants.parseDateTime(data['endDate']);
      if (isStatusActive && endDate != null && endDate.isAfter(now)) {
        final custId = data['customerId'] as String?;
        if (custId != null && custId.isNotEmpty) {
          activeCustomerIds.add(custId);
        }
      }
    }

    var list = snap.docs.map((d) {
      final model = CustomerModel.fromFirestore(d);
      final dynamicStatus = model.isArchived
          ? 'archived'
          : (activeCustomerIds.contains(model.id) ? 'active' : 'inactive');
      return model.copyWith(status: dynamicStatus);
    }).toList();

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
    final model = CustomerModel.fromFirestore(doc);

    final now = DateTime.now();
    final vpsSnap = await _firestore.collection('vps_services').where('customerId', isEqualTo: id).get();
    final hasActiveService = vpsSnap.docs.any((d) {
      final data = d.data();
      final status = (data['status'] as String? ?? '').toLowerCase();
      final isStatusActive = status == 'active' || status == 'actice';
      final endDate = AppConstants.parseDateTime(data['endDate']);
      return isStatusActive && endDate != null && endDate.isAfter(now);
    });

    final dynamicStatus = model.isArchived
        ? 'archived'
        : (hasActiveService ? 'active' : 'inactive');

    return model.copyWith(status: dynamicStatus);
  }

  /// Menghasilkan ID Pelanggan berurutan otomatis (contoh: CUS-021)
  /// berdasarkan data pelanggan yang ada di Firestore.
  Future<String> generateNextCustomerId() async {
    try {
      final snap = await _customersRef.get();
      final existingIds = snap.docs
          .map((doc) => (doc.data() as Map<String, dynamic>?)?['sourceId'] as String? ?? '')
          .toList();
      return calculateNextCustomerId(existingIds);
    } catch (e) {
      // Fallback jika query error / offline
      final now = DateTime.now();
      final fallbackNum = (now.millisecondsSinceEpoch % 900) + 100;
      return 'CUS-$fallbackNum';
    }
  }

  /// Menghitung ID sequential berikutnya dari daftar ID pelanggan yang ada.
  static String calculateNextCustomerId(Iterable<String> existingIds) {
    int maxNum = 0;
    final regExp = RegExp(r'(?:cus|customer|c)?\s*[-_]?\s*(\d+)', caseSensitive: false);

    for (final raw in existingIds) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      final match = regExp.firstMatch(id);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          final n = int.tryParse(numStr);
          if (n != null && n > 0 && n < 100000 && n > maxNum) {
            maxNum = n;
          }
        }
      }
    }

    final nextNum = maxNum + 1;
    return 'CUS-${nextNum.toString().padLeft(3, '0')}';
  }

  Future<String> addCustomer(CustomerModel customer) async {
    var effectiveCustomer = customer;
    if (effectiveCustomer.sourceId.trim().isEmpty) {
      final autoId = await generateNextCustomerId();
      effectiveCustomer = effectiveCustomer.copyWith(sourceId: autoId);
    }

    final docRef = _customersRef.doc(effectiveCustomer.id.isNotEmpty ? effectiveCustomer.id : null);
    await docRef.set(effectiveCustomer.toMap());

    // Log Activity
    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'CREATE_CUSTOMER',
      'category': 'CUSTOMERS',
      'details': 'Menambahkan pelanggan baru: ${effectiveCustomer.name} (${effectiveCustomer.sourceId})',
      'targetId': docRef.id,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Buat Notifikasi Sistem untuk Administrator & Staff
    await _firestore.collection('notifications').add({
      'title': 'Pelanggan Baru Terdaftar',
      'message': '${effectiveCustomer.name} (${effectiveCustomer.sourceId}) telah didaftarkan ke sistem.',
      'category': 'SYSTEM',
      'customerId': docRef.id,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
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
