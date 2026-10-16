import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final String category; // 'EXPIRATION', 'PAYMENT', 'INVOICE', 'SYSTEM'
  final String? serviceId;
  final String? customerId;
  final bool isRead;
  final DateTime? createdAt;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    this.serviceId,
    this.customerId,
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
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'category': category,
      'serviceId': serviceId,
      'customerId': customerId,
      'isRead': isRead,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
