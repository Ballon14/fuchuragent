import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

class PaymentModel {
  final String id;
  final String invoiceId;
  final String customerId;
  final String? serviceId;
  final int amount; // Integer IDR
  final DateTime? paymentDate;
  final String paymentMethod; // 'Transfer Bank', 'QRIS', 'Tunai', etc.
  final String referenceNumber;
  final String? receiptUrl;
  final String? recordedBy;
  final String notes;
  final bool isReversed;
  final String? reverseReason;
  final DateTime? reversedAt;
  final String? reversedBy;
  final String? idempotencyKey;
  final DateTime? createdAt;

  PaymentModel({
    required this.id,
    required this.invoiceId,
    required this.customerId,
    this.serviceId,
    required this.amount,
    this.paymentDate,
    this.paymentMethod = 'Transfer Bank',
    this.referenceNumber = '',
    this.receiptUrl,
    this.recordedBy,
    this.notes = '',
    this.isReversed = false,
    this.reverseReason,
    this.reversedAt,
    this.reversedBy,
    this.idempotencyKey,
    this.createdAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentModel(
      id: doc.id,
      invoiceId: data['invoiceId'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      serviceId: data['serviceId'] as String?,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paymentDate: AppConstants.parseDateTime(data['paymentDate']),
      paymentMethod: data['paymentMethod'] as String? ?? 'Transfer Bank',
      referenceNumber: data['referenceNumber'] as String? ?? '',
      receiptUrl: data['receiptUrl'] as String?,
      recordedBy: data['recordedBy'] as String?,
      notes: data['notes'] as String? ?? '',
      isReversed: data['isReversed'] as bool? ?? false,
      reverseReason: data['reverseReason'] as String?,
      reversedAt: AppConstants.parseDateTime(data['reversedAt']),
      reversedBy: data['reversedBy'] as String?,
      idempotencyKey: data['idempotencyKey'] as String?,
      createdAt: AppConstants.parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceId': invoiceId,
      'customerId': customerId,
      'serviceId': serviceId,
      'amount': amount,
      'paymentDate': paymentDate != null ? Timestamp.fromDate(paymentDate!) : FieldValue.serverTimestamp(),
      'paymentMethod': paymentMethod,
      'referenceNumber': referenceNumber,
      'receiptUrl': receiptUrl,
      'recordedBy': recordedBy,
      'notes': notes,
      'isReversed': isReversed,
      'reverseReason': reverseReason,
      'reversedAt': reversedAt != null ? Timestamp.fromDate(reversedAt!) : null,
      'reversedBy': reversedBy,
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
