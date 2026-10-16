import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceItem {
  final String description;
  final int unitPrice;
  final int quantity;
  final int total;

  InvoiceItem({
    required this.description,
    required this.unitPrice,
    this.quantity = 1,
    required this.total,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      description: map['description'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'total': total,
    };
  }
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String? serviceId;
  final List<InvoiceItem> items;
  final int subtotal;
  final int discount;
  final int total;
  final int paidAmount;
  final String status; // 'draft', 'unpaid', 'partial', 'paid', 'overdue', 'cancelled'
  final DateTime? issuedAt;
  final DateTime? dueDate;
  final String notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    this.serviceId,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    this.paidAmount = 0,
    this.status = 'unpaid',
    this.issuedAt,
    this.dueDate,
    this.notes = '',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPaid => status == 'paid' || paidAmount >= total && total > 0;
  bool get isPartial => status == 'partial';
  bool get isOverdue {
    if (isPaid || status == 'cancelled') return false;
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  int get remainingBalance => (total - paidAmount).clamp(0, total);

  factory InvoiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems.map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>)).toList();

    return InvoiceModel(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] as String? ?? 'INV-${doc.id.substring(0, 6)}',
      customerId: data['customerId'] as String? ?? '',
      serviceId: data['serviceId'] as String?,
      items: itemsList,
      subtotal: (data['subtotal'] as num?)?.toInt() ?? 0,
      discount: (data['discount'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toInt() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'unpaid',
      issuedAt: (data['issuedAt'] as Timestamp?)?.toDate(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String? ?? '',
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'serviceId': serviceId,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paidAmount': paidAmount,
      'status': status,
      'issuedAt': issuedAt != null ? Timestamp.fromDate(issuedAt!) : null,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
