import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class ExpenseModel {
  final String id;
  final String expenseNumber;
  final String title;
  final String category; // 'SERVER', 'LICENSE', 'WORKER', 'DOMAIN', 'NETWORK', 'OPERATIONAL', 'OTHER'
  final int amount; // Integer IDR
  final DateTime expenseDate;
  final String recipient; // Vendor / Person
  final String paymentMethod; // 'Transfer Bank', 'BCA', 'Mandiri', 'PayPal', 'Cash', 'QRIS'
  final String notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.id,
    this.expenseNumber = '',
    required this.title,
    this.category = 'OPERATIONAL',
    required this.amount,
    required this.expenseDate,
    this.recipient = '',
    this.paymentMethod = 'Transfer Bank',
    this.notes = '',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  String get categoryLabel {
    switch (category.toUpperCase()) {
      case 'SERVER':
        return 'Server & Infra';
      case 'LICENSE':
        return 'Lisensi Software';
      case 'WORKER':
        return 'Upah / Gaji Worker';
      case 'DOMAIN':
        return 'Domain & SSL';
      case 'NETWORK':
        return 'Jaringan & Bandwidth';
      case 'OPERATIONAL':
        return 'Operasional Kantor';
      case 'OTHER':
      default:
        return 'Lain-lain';
    }
  }

  IconData get categoryIcon {
    switch (category.toUpperCase()) {
      case 'SERVER':
        return Icons.dns_rounded;
      case 'LICENSE':
        return Icons.verified_user_rounded;
      case 'WORKER':
        return Icons.badge_rounded;
      case 'DOMAIN':
        return Icons.language_rounded;
      case 'NETWORK':
        return Icons.hub_rounded;
      case 'OPERATIONAL':
        return Icons.business_rounded;
      case 'OTHER':
      default:
        return Icons.receipt_rounded;
    }
  }

  Color get categoryColor {
    switch (category.toUpperCase()) {
      case 'SERVER':
        return const Color(0xFF0284C7); // Sky / Blue
      case 'LICENSE':
        return const Color(0xFF8B5CF6); // Purple
      case 'WORKER':
        return const Color(0xFF10B981); // Emerald / Green
      case 'DOMAIN':
        return const Color(0xFFF59E0B); // Amber
      case 'NETWORK':
        return const Color(0xFFEC4899); // Pink
      case 'OPERATIONAL':
        return const Color(0xFF06B6D4); // Cyan
      case 'OTHER':
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ExpenseModel.fromMap(doc.id, data);
  }

  factory ExpenseModel.fromMap(String id, Map<String, dynamic> data) {
    return ExpenseModel(
      id: id,
      expenseNumber: data['expenseNumber'] as String? ?? '',
      title: data['title'] as String? ?? 'Pengeluaran',
      category: (data['category'] as String? ?? 'OPERATIONAL').toUpperCase(),
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      expenseDate: AppConstants.parseDateTime(data['expenseDate']) ?? DateTime.now(),
      recipient: data['recipient'] as String? ?? '',
      paymentMethod: data['paymentMethod'] as String? ?? 'Transfer Bank',
      notes: data['notes'] as String? ?? '',
      createdBy: data['createdBy'] as String?,
      createdAt: AppConstants.parseDateTime(data['createdAt']),
      updatedAt: AppConstants.parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expenseNumber': expenseNumber,
      'title': title,
      'category': category.toUpperCase(),
      'amount': amount,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'recipient': recipient,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? expenseNumber,
    String? title,
    String? category,
    int? amount,
    DateTime? expenseDate,
    String? recipient,
    String? paymentMethod,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      expenseNumber: expenseNumber ?? this.expenseNumber,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      recipient: recipient ?? this.recipient,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
