import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String category; // 'FINANCE', 'SERVICES', 'CUSTOMERS', 'SECURITY', 'IMPORT'
  final String details;
  final String? targetId;
  final DateTime? timestamp;

  ActivityLogModel({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.category,
    required this.details,
    this.targetId,
    this.timestamp,
  });

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ActivityLogModel(
      id: doc.id,
      actorId: data['actorId'] as String? ?? 'system',
      actorName: data['actorName'] as String? ?? 'System',
      action: data['action'] as String? ?? 'ACTION',
      category: data['category'] as String? ?? 'SYSTEM',
      details: data['details'] as String? ?? '',
      targetId: data['targetId'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorId': actorId,
      'actorName': actorName,
      'action': action,
      'category': category,
      'details': details,
      'targetId': targetId,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }
}
