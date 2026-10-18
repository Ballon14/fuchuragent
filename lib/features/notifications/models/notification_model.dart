import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final String category; // 'EXPIRATION', 'PAYMENT', 'INVOICE', 'SYSTEM'
  final String? serviceId;
  final String? customerId;
  final String? invoiceId;
  final bool isRead;
  final DateTime? createdAt;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    this.serviceId,
    this.customerId,
    this.invoiceId,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotificationModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Notifikasi',
      message: data['message'] as String? ?? '',
      category: data['category'] as String? ?? 'SYSTEM',
      serviceId: data['serviceId'] as String?,
      customerId: data['customerId'] as String?,
      invoiceId: data['invoiceId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory AppNotificationModel.fromMap(String id, Map<String, dynamic> data) {
    return AppNotificationModel(
      id: id,
      title: data['title'] as String? ?? 'Notifikasi',
      message: data['message'] as String? ?? '',
      category: data['category'] as String? ?? 'SYSTEM',
      serviceId: data['serviceId'] as String?,
      customerId: data['customerId'] as String?,
      invoiceId: data['invoiceId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime ? data['createdAt'] as DateTime : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'category': category,
      'serviceId': serviceId,
      'customerId': customerId,
      'invoiceId': invoiceId,
      'isRead': isRead,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? category,
    String? serviceId,
    String? customerId,
    String? invoiceId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      serviceId: serviceId ?? this.serviceId,
      customerId: customerId ?? this.customerId,
      invoiceId: invoiceId ?? this.invoiceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
