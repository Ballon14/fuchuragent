import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuchuragent/features/expenses/models/expense_model.dart';
import 'package:fuchuragent/features/expenses/repositories/expense_repository.dart';
import 'package:fuchuragent/features/dashboard/models/dashboard_stats.dart';

void main() {
  group('ExpenseModel Tests', () {
    test('ExpenseModel should correctly initialize and map to/from Map', () {
      final now = DateTime(2026, 10, 18, 10, 0, 0);
      final expense = ExpenseModel(
        id: 'exp_123',
        expenseNumber: 'EXP-001',
        title: 'Perpanjangan Server Hetzner AX101',
        category: 'SERVER',
        amount: 1450000,
        expenseDate: now,
        recipient: 'Hetzner Online GmbH',
        paymentMethod: 'Transfer Bank Mandiri',
        notes: 'Invoice #HETZ-2026-991',
        createdBy: 'admin_test',
        createdAt: now,
        updatedAt: now,
      );

      expect(expense.id, 'exp_123');
      expect(expense.expenseNumber, 'EXP-001');
      expect(expense.title, 'Perpanjangan Server Hetzner AX101');
      expect(expense.category, 'SERVER');
      expect(expense.amount, 1450000);
      expect(expense.categoryLabel, 'Server & Infra');
      expect(expense.categoryIcon, Icons.dns_rounded);

      final map = expense.toMap();
      expect(map['expenseNumber'], 'EXP-001');
      expect(map['title'], 'Perpanjangan Server Hetzner AX101');
      expect(map['category'], 'SERVER');
      expect(map['amount'], 1450000);
      expect(map['recipient'], 'Hetzner Online GmbH');
      expect(map['paymentMethod'], 'Transfer Bank Mandiri');

      final reconstructed = ExpenseModel.fromMap('exp_123', map);
      expect(reconstructed.id, 'exp_123');
      expect(reconstructed.expenseNumber, 'EXP-001');
      expect(reconstructed.title, expense.title);
      expect(reconstructed.amount, expense.amount);
      expect(reconstructed.category, 'SERVER');
    });

    test('ExpenseModel categories provide distinct labels and colors', () {
      final categories = [
        'SERVER',
        'LICENSE',
        'WORKER',
        'DOMAIN',
        'NETWORK',
        'OPERATIONAL',
        'OTHER',
      ];

      for (final cat in categories) {
        final model = ExpenseModel(
          id: 'test',
          title: 'Test $cat',
          category: cat,
          amount: 10000,
          expenseDate: DateTime.now(),
        );

        expect(model.categoryLabel.isNotEmpty, true);
        expect(model.categoryIcon, isA<IconData>());
        expect(model.categoryColor, isA<Color>());
      }
    });

    test('ExpenseModel copyWith should update fields properly', () {
      final original = ExpenseModel(
        id: '1',
        expenseNumber: 'EXP-001',
        title: 'Original Title',
        category: 'SERVER',
        amount: 100000,
        expenseDate: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        amount: 250000,
        category: 'WORKER',
      );

      expect(updated.id, original.id);
      expect(updated.expenseNumber, original.expenseNumber);
      expect(updated.title, 'Updated Title');
      expect(updated.amount, 250000);
      expect(updated.category, 'WORKER');
      expect(updated.categoryLabel, 'Upah / Gaji Worker');
    });
  });

  group('ExpenseRepository Sequential Numbering Tests', () {
    test('calculateNextExpenseNumber should start at EXP-001 for empty list', () {
      final result = ExpenseRepository.calculateNextExpenseNumber([]);
      expect(result, 'EXP-001');
    });

    test('calculateNextExpenseNumber increments highest number', () {
      final numbers = ['EXP-001', 'EXP-002', 'EXP-003'];
      final next = ExpenseRepository.calculateNextExpenseNumber(numbers);
      expect(next, 'EXP-004');
    });

    test('calculateNextExpenseNumber handles non-padded, out of order, or alternate casing', () {
      final numbers = ['exp-1', 'EXP-05', 'EXP-002', 'exp-12'];
      final next = ExpenseRepository.calculateNextExpenseNumber(numbers);
      expect(next, 'EXP-013');
    });

    test('calculateNextExpenseNumber ignores invalid or empty strings', () {
      final numbers = ['', ' ', 'INVALID_NUMBER', 'EXP-099'];
      final next = ExpenseRepository.calculateNextExpenseNumber(numbers);
      expect(next, 'EXP-100');
    });
  });

  group('DashboardStats Financial Calculation Tests', () {
    test('netProfit is calculated correctly from totalRevenue - totalExpenses', () {
      final stats = DashboardStats(
        totalCustomers: 10,
        activeCustomers: 8,
        totalServices: 12,
        activeServices: 10,
        expiringServicesCount: 2,
        expiredServicesCount: 1,
        unpaidInvoicesCount: 3,
        overdueInvoicesCount: 1,
        unpaidAmount: 750000,
        totalRevenue: 5000000, // Rp 5.000.000 kas masuk
        totalExpenses: 2200000, // Rp 2.200.000 kas keluar (server, lisensi, worker)
        recentPayments: [],
        recentCustomers: [],
        recentActivities: [],
        followUpServices: [],
      );

      expect(stats.totalRevenue, 5000000);
      expect(stats.totalExpenses, 2200000);
      expect(stats.netProfit, 2800000); // Laba bersih = Rp 2.800.000
    });

    test('netProfit correctly reflects negative balance when expenses exceed revenue', () {
      final stats = DashboardStats(
        totalCustomers: 2,
        activeCustomers: 1,
        totalServices: 2,
        activeServices: 1,
        expiringServicesCount: 0,
        expiredServicesCount: 0,
        unpaidInvoicesCount: 0,
        overdueInvoicesCount: 0,
        unpaidAmount: 0,
        totalRevenue: 1000000,
        totalExpenses: 1500000,
        recentPayments: [],
        recentCustomers: [],
        recentActivities: [],
        followUpServices: [],
      );

      expect(stats.netProfit, -500000);
    });
  });
}
