import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

class CustomerModel {
  final String id;
  final String sourceId;
  final String name;
  final String phone;
  final String? email;
  final String status; // 'active' | 'inactive' | 'archived'
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerModel({
    required this.id,
    this.sourceId = '',
    required this.name,
    required this.phone,
    this.email,
    this.status = 'active',
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isArchived => status == 'archived';

  factory CustomerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomerModel(
      id: doc.id,
      sourceId: data['sourceId'] as String? ?? '',
      name: data['name'] as String? ?? 'Pelanggan Tanpa Nama',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String?,
      status: data['status'] as String? ?? 'active',
      notes: data['notes'] as String? ?? '',
      createdAt: AppConstants.parseDateTime(data['createdAt']),
      updatedAt: AppConstants.parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourceId': sourceId,
      'name': name,
      'phone': phone,
      'email': email,
      'status': status,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? sourceId,
    String? name,
    String? phone,
    String? email,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
