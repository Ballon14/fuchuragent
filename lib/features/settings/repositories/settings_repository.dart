import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/system_settings_model.dart';

class DatabaseStats {
  final int totalCustomers;
  final int totalServices;
  final int totalInvoices;
  final int totalExpenses;
  final int totalAuditLogs;
  final DateTime lastChecked;

  const DatabaseStats({
    required this.totalCustomers,
    required this.totalServices,
    required this.totalInvoices,
    required this.totalExpenses,
    required this.totalAuditLogs,
    required this.lastChecked,
  });

  factory DatabaseStats.empty() => DatabaseStats(
        totalCustomers: 0,
        totalServices: 0,
        totalInvoices: 0,
        totalExpenses: 0,
        totalAuditLogs: 0,
        lastChecked: DateTime.now(),
      );
}

class SettingsRepository {
  final FirebaseFirestore _firestore;

  SettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _settingsCollection = 'settings';
  static const String _configDoc = 'system_config';

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection(_settingsCollection).doc(_configDoc);

  /// Fetch settings from Firestore or return baseline defaults
  Future<SystemSettingsModel> getSettings() async {
    try {
      final doc = await _configRef.get();
      if (doc.exists && doc.data() != null) {
        return SystemSettingsModel.fromMap(doc.data()!);
      }
      return SystemSettingsModel.defaultSettings();
    } catch (e) {
      debugPrint('Error getting settings from Firestore: $e');
      return SystemSettingsModel.defaultSettings();
    }
  }


  /// Watch settings in real-time
  Stream<SystemSettingsModel> watchSettings() {
    return _configRef.snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return SystemSettingsModel.fromMap(snapshot.data()!);
      }
      return SystemSettingsModel.defaultSettings();
    }).handleError((err) {
      debugPrint('Error watching settings stream: $err');
      return SystemSettingsModel.defaultSettings();
    });
  }

  /// Save settings to Firestore
  Future<void> saveSettings(SystemSettingsModel settings, {String? updatedBy}) async {
    final updated = settings.copyWith(
      updatedAt: DateTime.now(),
      updatedBy: updatedBy ?? 'Admin',
    );
    await _configRef.set(updated.toMap(), SetOptions(merge: true));
  }

  /// Add a new dynamic payment method (e.g. new bank account / QRIS)
  Future<void> addPaymentMethod(PaymentMethodModel newMethod, {String? updatedBy}) async {
    final current = await getSettings();
    final methods = List<PaymentMethodModel>.from(current.paymentMethods);

    // If new method is marked as default, clear default flag from others
    if (newMethod.isDefault) {
      for (int i = 0; i < methods.length; i++) {
        methods[i] = methods[i].copyWith(isDefault: false);
      }
    }

    methods.add(newMethod);
    final updated = current.copyWith(paymentMethods: methods);
    await saveSettings(updated, updatedBy: updatedBy);
  }

  /// Update an existing dynamic payment method (e.g. changing account number, bank name, or holder)
  Future<void> updatePaymentMethod(PaymentMethodModel updatedMethod, {String? updatedBy}) async {
    final current = await getSettings();
    final methods = List<PaymentMethodModel>.from(current.paymentMethods);
    final index = methods.indexWhere((m) => m.id == updatedMethod.id);

    if (index >= 0) {
      if (updatedMethod.isDefault) {
        for (int i = 0; i < methods.length; i++) {
          methods[i] = methods[i].copyWith(isDefault: false);
        }
      }
      methods[index] = updatedMethod;
      final updated = current.copyWith(paymentMethods: methods);
      await saveSettings(updated, updatedBy: updatedBy);
    }
  }

  /// Delete a dynamic payment method
  Future<void> deletePaymentMethod(String methodId, {String? updatedBy}) async {
    final current = await getSettings();
    final methods = List<PaymentMethodModel>.from(current.paymentMethods);
    methods.removeWhere((m) => m.id == methodId);
    final updated = current.copyWith(paymentMethods: methods);
    await saveSettings(updated, updatedBy: updatedBy);
  }

  /// Toggle active/inactive status of a payment method
  Future<void> togglePaymentMethodStatus(String methodId, bool isActive, {String? updatedBy}) async {
    final current = await getSettings();
    final methods = List<PaymentMethodModel>.from(current.paymentMethods);
    final index = methods.indexWhere((m) => m.id == methodId);
    if (index >= 0) {
      methods[index] = methods[index].copyWith(isActive: isActive);
      final updated = current.copyWith(paymentMethods: methods);
      await saveSettings(updated, updatedBy: updatedBy);
    }
  }

  /// Reset settings back to initial defaults
  Future<void> resetToDefaults({String? updatedBy}) async {
    final defaults = SystemSettingsModel.defaultSettings().copyWith(
      updatedAt: DateTime.now(),
      updatedBy: updatedBy ?? 'Admin (Reset)',
    );
    await _configRef.set(defaults.toMap());
  }

  /// Get real-time document counts from core Firestore collections
  Future<DatabaseStats> getDatabaseStats() async {
    try {
      final customersCountFuture = _firestore.collection('customers').count().get();
      final servicesCountFuture = _firestore.collection('vps_services').count().get();
      final invoicesCountFuture = _firestore.collection('invoices').count().get();
      final expensesCountFuture = _firestore.collection('expenses').count().get();
      final auditLogsCountFuture = _firestore.collection('activity_logs').count().get();

      final results = await Future.wait([
        customersCountFuture,
        servicesCountFuture,
        invoicesCountFuture,
        expensesCountFuture,
        auditLogsCountFuture,
      ]);

      return DatabaseStats(
        totalCustomers: results[0].count ?? 0,
        totalServices: results[1].count ?? 0,
        totalInvoices: results[2].count ?? 0,
        totalExpenses: results[3].count ?? 0,
        totalAuditLogs: results[4].count ?? 0,
        lastChecked: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error retrieving database statistics: $e');
      return DatabaseStats.empty();
    }
  }

  /// Exports an entire system snapshot (customers, services, invoices, expenses, settings) as structured JSON
  Future<String> exportSystemBackupJson() async {
    try {
      final customersSnap = await _firestore.collection('customers').get();
      final servicesSnap = await _firestore.collection('vps_services').get();
      final invoicesSnap = await _firestore.collection('invoices').get();
      final expensesSnap = await _firestore.collection('expenses').get();
      final settingsDoc = await _configRef.get();
      final settingsData = settingsDoc.data() ?? SystemSettingsModel.defaultSettings().toMap();
      final resolvedAppName = (settingsData['brandName'] as String?)?.isNotEmpty == true
          ? settingsData['brandName']
          : 'Fuchur Agent';

      final backupData = {
        'version': '1.0.0',
        'exportDate': DateTime.now().toIso8601String(),
        'appName': resolvedAppName,
        'counts': {
          'customers': customersSnap.docs.length,
          'services': servicesSnap.docs.length,
          'invoices': invoicesSnap.docs.length,
          'expenses': expensesSnap.docs.length,
        },
        'settings': settingsData,
        'customers': customersSnap.docs.map((d) => d.data()).toList(),
        'services': servicesSnap.docs.map((d) => d.data()).toList(),
        'invoices': invoicesSnap.docs.map((d) => d.data()).toList(),
        'expenses': expensesSnap.docs.map((d) => d.data()).toList(),
      };

      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(backupData);
    } catch (e) {
      debugPrint('Error exporting database backup: $e');
      rethrow;
    }
  }
}
