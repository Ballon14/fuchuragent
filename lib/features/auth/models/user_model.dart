import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String role; // 'superadmin' | 'admin' | 'staff'
  final String phone;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const String superAdminEmail = 'iqbal140605@gmail.com';

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.role = 'staff',
    this.phone = '',
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get isSuperAdmin => email.toLowerCase().trim() == superAdminEmail || role == 'superadmin';
  bool get isAdmin => role == 'admin' || isSuperAdmin;

  String get roleLabel {
    if (isSuperAdmin) return 'Super Admin';
    if (role == 'admin') return 'Administrator';
    return 'Staf Teknis';
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      email: data['email'] as String? ?? '',
      name: data['name'] as String? ?? '',
      role: data['role'] as String? ?? 'staff',
      phone: data['phone'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? phone,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
