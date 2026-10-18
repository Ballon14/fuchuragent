import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _expensesRef => _firestore.collection('expenses');

  /// Memantau daftar pengeluaran secara realtime
  Stream<List<ExpenseModel>> watchExpenses({String? categoryFilter}) {
    return _expensesRef.snapshots().map((snap) {
      var list = snap.docs.map((d) => ExpenseModel.fromFirestore(d)).toList();

      if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'all') {
        list = list.where((e) => e.category.toLowerCase() == categoryFilter.toLowerCase()).toList();
      }

      list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return list;
    });
  }

  /// Mengambil data pengeluaran dengan filter pencarian dan batas limit
  Future<List<ExpenseModel>> getExpenses({
    String? searchQuery,
    String? categoryFilter,
    int limit = 100,
  }) async {
    final snap = await _expensesRef.limit(250).get();
    var list = snap.docs.map((d) => ExpenseModel.fromFirestore(d)).toList();

    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'all') {
      list = list.where((e) => e.category.toLowerCase() == categoryFilter.toLowerCase()).toList();
    }

    list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.expenseNumber.toLowerCase().contains(q) ||
            e.recipient.toLowerCase().contains(q) ||
            e.categoryLabel.toLowerCase().contains(q) ||
            e.paymentMethod.toLowerCase().contains(q);
      }).toList();
    }

    return list.take(limit).toList();
  }

  Future<ExpenseModel?> getExpenseById(String id) async {
    final doc = await _expensesRef.doc(id).get();
    if (!doc.exists) return null;
    return ExpenseModel.fromFirestore(doc);
  }

  /// Menghasilkan nomor pengeluaran sequential (contoh: EXP-001)
  Future<String> generateNextExpenseNumber() async {
    try {
      final snap = await _expensesRef.get();
      final existingNumbers = snap.docs
          .map((d) => (d.data() as Map<String, dynamic>?)?['expenseNumber'] as String? ?? '')
          .toList();
      return calculateNextExpenseNumber(existingNumbers);
    } catch (_) {
      final now = DateTime.now();
      final numFallback = (now.millisecondsSinceEpoch % 900) + 100;
      return 'EXP-$numFallback';
    }
  }

  static String calculateNextExpenseNumber(Iterable<String> existingNumbers) {
    int maxNum = 0;
    final regExp = RegExp(r'(?:exp|expense)?\s*[-_]?\s*(\d+)', caseSensitive: false);

    for (final raw in existingNumbers) {
      final numStr = raw.trim();
      if (numStr.isEmpty) continue;
      final match = regExp.firstMatch(numStr);
      if (match != null) {
        final val = int.tryParse(match.group(1) ?? '');
        if (val != null && val > maxNum && val < 100000) {
          maxNum = val;
        }
      }
    }

    final nextNum = maxNum + 1;
    return 'EXP-${nextNum.toString().padLeft(3, '0')}';
  }

  /// Menambahkan pencatatan pengeluaran baru
  Future<String> addExpense(ExpenseModel expense) async {
    var effectiveExpense = expense;
    if (effectiveExpense.expenseNumber.trim().isEmpty) {
      final autoNum = await generateNextExpenseNumber();
      effectiveExpense = effectiveExpense.copyWith(expenseNumber: autoNum);
    }

    final docRef = _expensesRef.doc(effectiveExpense.id.isNotEmpty ? effectiveExpense.id : null);
    final user = _auth.currentUser;
    final payload = effectiveExpense.copyWith(
      id: docRef.id,
      createdBy: effectiveExpense.createdBy ?? user?.email ?? 'Admin',
    ).toMap();

    await docRef.set(payload);

    // Audit Log
    await _firestore.collection('activity_logs').add({
      'actorId': user?.uid ?? 'system',
      'actorName': user?.email ?? 'Admin',
      'action': 'CREATE_EXPENSE',
      'category': 'FINANCE',
      'details': 'Mencatat pengeluaran: ${effectiveExpense.title} (${AppConstants.formatRupiah(effectiveExpense.amount)})',
      'targetId': docRef.id,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Notifikasi Sistem
    await _firestore.collection('notifications').add({
      'title': 'Pengeluaran Dicatat',
      'message': 'Pengeluaran ${effectiveExpense.expenseNumber} sebesar ${AppConstants.formatRupiah(effectiveExpense.amount)} untuk ${effectiveExpense.title} telah dicatat.',
      'category': 'FINANCE',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Memperbarui data pengeluaran
  Future<void> updateExpense(ExpenseModel expense) async {
    await _expensesRef.doc(expense.id).update(expense.toMap());

    final user = _auth.currentUser;
    await _firestore.collection('activity_logs').add({
      'actorId': user?.uid ?? 'system',
      'actorName': user?.email ?? 'Admin',
      'action': 'UPDATE_EXPENSE',
      'category': 'FINANCE',
      'details': 'Memperbarui pengeluaran: ${expense.title} (${expense.expenseNumber})',
      'targetId': expense.id,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Menghapus pengeluaran
  Future<void> deleteExpense(String id, {String? title, int? amount}) async {
    await _expensesRef.doc(id).delete();

    final user = _auth.currentUser;
    await _firestore.collection('activity_logs').add({
      'actorId': user?.uid ?? 'system',
      'actorName': user?.email ?? 'Admin',
      'action': 'DELETE_EXPENSE',
      'category': 'FINANCE',
      'details': 'Menghapus catatan pengeluaran ID: $id ${title != null ? "($title)" : ""}',
      'targetId': id,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Menghitung total seluruh pengeluaran
  Future<int> getTotalExpenses({DateTime? start, DateTime? end}) async {
    final snap = await _expensesRef.get();
    int sum = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      final date = AppConstants.parseDateTime(data['expenseDate']);
      if (date != null) {
        if (start != null && date.isBefore(start)) continue;
        if (end != null && date.isAfter(end)) continue;
      }
      sum += amount;
    }
    return sum;
  }
}
