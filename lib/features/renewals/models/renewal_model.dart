import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRenewalModel {
  final String id;
  final String serviceId;
  final String customerId;
  final DateTime? previousEndDate;
  final DateTime? newEndDate;
  final int durationMonths;
  final String? invoiceId;
  final String? adminId;
  final String notes;
  final String? idempotencyKey;
  final DateTime? createdAt;

  ServiceRenewalModel({
    required this.id,
    required this.serviceId,
    required this.customerId,
    this.previousEndDate,
    this.newEndDate,
    this.durationMonths = 1,
    this.invoiceId,
    this.adminId,
    this.notes = '',
    this.idempotencyKey,
    this.createdAt,
  });

  factory ServiceRenewalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceRenewalModel(
      id: doc.id,
      serviceId: data['serviceId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      previousEndDate: (data['previousEndDate'] as Timestamp?)?.toDate(),
      newEndDate: (data['newEndDate'] as Timestamp?)?.toDate(),
      durationMonths: (data['durationMonths'] as num?)?.toInt() ?? 1,
      invoiceId: data['invoiceId'] as String?,
      adminId: data['adminId'] as String?,
      notes: data['notes'] as String? ?? '',
      idempotencyKey: data['idempotencyKey'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'customerId': customerId,
      'previousEndDate': previousEndDate != null ? Timestamp.fromDate(previousEndDate!) : null,
      'newEndDate': newEndDate != null ? Timestamp.fromDate(newEndDate!) : null,
      'durationMonths': durationMonths,
      'invoiceId': invoiceId,
      'adminId': adminId,
      'notes': notes,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
