import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

class ActivityLogModel {
  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String category; // 'FINANCE', 'SERVICES', 'CUSTOMERS', 'SECURITY', 'PACKAGES', 'IMPORT', 'SYSTEM'
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
    return ActivityLogModel.fromMap(doc.id, data);
  }

  factory ActivityLogModel.fromMap(String id, Map<String, dynamic> data) {
    return ActivityLogModel(
      id: id,
      actorId: data['actorId'] as String? ?? 'system',
      actorName: data['actorName'] as String? ?? 'System',
      action: data['action'] as String? ?? 'ACTION',
      category: (data['category'] as String? ?? 'SYSTEM').toUpperCase(),
      details: data['details'] as String? ?? '',
      targetId: data['targetId'] as String?,
      timestamp: AppConstants.parseDateTime(data['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorId': actorId,
      'actorName': actorName,
      'action': action,
      'category': category.toUpperCase(),
      'details': details,
      'targetId': targetId,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }

  ActivityLogModel copyWith({
    String? id,
    String? actorId,
    String? actorName,
    String? action,
    String? category,
    String? details,
    String? targetId,
    DateTime? timestamp,
  }) {
    return ActivityLogModel(
      id: id ?? this.id,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      action: action ?? this.action,
      category: category ?? this.category,
      details: details ?? this.details,
      targetId: targetId ?? this.targetId,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
