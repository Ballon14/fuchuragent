import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import '../../customers/models/customer_model.dart';
import '../../services/models/service_model.dart';
import '../../expenses/models/expense_model.dart';
import '../../invoices/models/invoice_model.dart';
import '../../payments/models/payment_model.dart';
import '../models/google_sheets_backup_model.dart';

class GoogleSheetsBackupService {
  static const String defaultSpreadsheetUrl =
      'https://docs.google.com/spreadsheets/d/1Rdcg6rgp4K7qBO328qeqHfzpaaYZjcRgvsI_OQGjLkE/edit?usp=sharing';

  final FirebaseFirestore? _firestore;

  GoogleSheetsBackupService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Formats date to match Google Sheets format (M/d/yyyy)
  static String formatSheetDate(DateTime? date) {
    if (date == null) return '';
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Formats nominal currency string for VPS sheet (e.g. "Rp77,000.00")
  static String formatVpsCurrency(int amount) {
    // Format: Rp77,000.00 style
    final rawNumber = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return 'Rp$rawNumber.00';
  }

  /// Formats nominal currency string for Expense sheet (e.g. "Rp30,000")
  static String formatExpenseCurrency(int amount) {
    final rawNumber = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return 'Rp$rawNumber';
  }

  /// Converts 2D List to TSV (Tab-Separated Values) format for clipboard pasting
  static String convertToTsv(List<List<dynamic>> rows) {
    return rows.map((row) => row.map((cell) => cell?.toString() ?? '').join('\t')).join('\n');
  }

  /// Compiles all collections into a comprehensive GoogleSheetsBackupBundle
  Future<GoogleSheetsBackupBundle> prepareBackupFromFirestore({
    String spreadsheetUrl = defaultSpreadsheetUrl,
  }) async {
    // 1. Fetch all collections from Firestore
    final customersSnap = await _db.collection('customers').get();
    final servicesSnap = await _db.collection('vps_services').get();
    final expensesSnap = await _db.collection('expenses').get();
    final invoicesSnap = await _db.collection('invoices').get();
    final paymentsSnap = await _db.collection('payments').get();

    final customers = customersSnap.docs.map((d) => CustomerModel.fromFirestore(d)).toList();
    final services = servicesSnap.docs.map((d) => VpsServiceModel.fromFirestore(d)).toList();
    final expenses = expensesSnap.docs.map((d) => ExpenseModel.fromFirestore(d)).toList();
    final invoices = invoicesSnap.docs.map((d) => InvoiceModel.fromFirestore(d)).toList();
    final payments = paymentsSnap.docs.map((d) => PaymentModel.fromFirestore(d)).toList();

    return processBackupBundle(
      spreadsheetUrl: spreadsheetUrl,
      customers: customers,
      services: services,
      expenses: expenses,
      invoices: invoices,
      payments: payments,
    );
  }

  /// Pure processing function from lists to backup bundle (100% testable without Firestore)
  GoogleSheetsBackupBundle processBackupBundle({
    String spreadsheetUrl = defaultSpreadsheetUrl,
    required List<CustomerModel> customers,
    required List<VpsServiceModel> services,
    required List<ExpenseModel> expenses,
    required List<InvoiceModel> invoices,
    required List<PaymentModel> payments,
  }) {
    final customerMap = <String, CustomerModel>{for (final c in customers) c.id: c};

    // -------------------------------------------------------------
    // SHEET 1: VPS / DAFTAR CUSTOMER VPS FUCHURHOST SOLUTIONS
    // Kolom: No, ID Customer, Nomor HP, Paket, Domain, Optional, Nominal, Payment Status, Mulai, Akhir, Worker , Payment Worker, Status
    // -------------------------------------------------------------
    final vpsRows = <List<dynamic>>[];
    vpsRows.add([
      'No',
      'ID Customer',
      'Nomor HP',
      'Paket',
      'Domain',
      'Optional',
      'Nominal',
      'Payment Status',
      'Mulai',
      'Akhir',
      'Worker ',
      'Payment Worker',
      'Status',
    ]);

    // Group services by customer or loop services
    int vpsRowIndex = 1;
    for (final s in services) {
      final cust = customerMap[s.customerId];
      final custPhone = cust?.phone ?? '';
      final custId = cust != null && cust.id.isNotEmpty
          ? (cust.sourceId.isNotEmpty
              ? cust.sourceId
              : (cust.id.startsWith('Cus-') ? cust.id : 'Cus-${cust.id.length > 4 ? cust.id.substring(0, 4).toUpperCase() : cust.id.toUpperCase()}'))
          : 'Cus-000';

      vpsRows.add([
        vpsRowIndex++,
        custId,
        custPhone,
        s.packageName.isNotEmpty ? s.packageName : 'Snipe-it Basic',
        s.domain.isNotEmpty ? s.domain : s.serviceName,
        s.deploymentType.isNotEmpty ? s.deploymentType : 'Publish',
        formatVpsCurrency(s.price),
        s.isActive ? 'Lunas' : 'Belum Lunas',
        formatSheetDate(s.startDate),
        formatSheetDate(s.endDate),
        (s.worker != null && s.worker!.isNotEmpty) ? s.worker! : 'Iqbal',
        s.workerPaid ? 'TRUE' : 'FALSE',
        s.isActive ? 'Active' : 'Deactive',
      ]);
    }

    // -------------------------------------------------------------
    // SHEET 2: Pengeluaran
    // Kolom: No, Nama , Total, Tanggal
    // -------------------------------------------------------------
    final expenseRows = <List<dynamic>>[];
    expenseRows.add([
      'No',
      'Nama ',
      'Total',
      'Tanggal',
    ]);

    int expIndex = 1;
    for (final e in expenses) {
      expenseRows.add([
        expIndex++,
        e.title,
        formatExpenseCurrency(e.amount),
        formatSheetDate(e.expenseDate),
      ]);
    }

    // -------------------------------------------------------------
    // SHEET 3: Tagihan & Invoice
    // Kolom: No, Nomor Invoice, ID Customer, Nama Pelanggan, Subtotal, Diskon, Total, Terbayar, Status, Jatuh Tempo, Catatan
    // -------------------------------------------------------------
    final invoiceRows = <List<dynamic>>[];
    invoiceRows.add([
      'No',
      'Nomor Invoice',
      'ID Customer',
      'Nama Pelanggan',
      'Subtotal',
      'Diskon',
      'Total Tagihan',
      'Terbayar',
      'Status',
      'Jatuh Tempo',
      'Catatan',
    ]);

    int invIndex = 1;
    for (final inv in invoices) {
      final cust = customerMap[inv.customerId];
      invoiceRows.add([
        invIndex++,
        inv.invoiceNumber,
        inv.customerId,
        cust?.name ?? 'Pelanggan',
        inv.subtotal,
        inv.discount,
        inv.total,
        inv.paidAmount,
        inv.status.toUpperCase(),
        formatSheetDate(inv.dueDate),
        inv.notes,
      ]);
    }

    // -------------------------------------------------------------
    // SHEET 4: Riwayat Pembayaran
    // Kolom: No, ID Pembayaran, Nomor Invoice, Nama Pelanggan, Nominal, Metode, No Referensi, Tanggal Bayar, Catatan
    // -------------------------------------------------------------
    final paymentRows = <List<dynamic>>[];
    paymentRows.add([
      'No',
      'ID Pembayaran',
      'Nomor Invoice',
      'Nama Pelanggan',
      'Nominal (Rp)',
      'Metode Pembayaran',
      'No Referensi',
      'Tanggal Bayar',
      'Catatan',
    ]);

    int payIndex = 1;
    for (final p in payments) {
      final cust = customerMap[p.customerId];
      paymentRows.add([
        payIndex++,
        p.id,
        p.invoiceId,
        cust?.name ?? 'Pelanggan',
        p.amount,
        p.paymentMethod,
        p.referenceNumber,
        formatSheetDate(p.paymentDate),
        p.notes,
      ]);
    }

    // Generate CSV and TSV strings
    final vpsCsv = csv.encode(vpsRows);
    final vpsTsv = convertToTsv(vpsRows);

    final expenseCsv = csv.encode(expenseRows);
    final expenseTsv = convertToTsv(expenseRows);

    final invoiceCsv = csv.encode(invoiceRows);
    final invoiceTsv = convertToTsv(invoiceRows);

    final paymentCsv = csv.encode(paymentRows);
    final paymentTsv = convertToTsv(paymentRows);

    // Full system JSON snapshot
    final fullSnapshotMap = {
      'metadata': {
        'appName': 'Fuchur Agent',
        'generatedAt': DateTime.now().toIso8601String(),
        'targetSpreadsheet': spreadsheetUrl,
      },
      'counts': {
        'customers': customers.length,
        'vps_services': services.length,
        'expenses': expenses.length,
        'invoices': invoices.length,
        'payments': payments.length,
      },
      'customers': customers.map((c) => c.toMap()).toList(),
      'vps_services': services.map((s) => s.toMap()).toList(),
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'invoices': invoices.map((inv) => inv.toMap()).toList(),
      'payments': payments.map((p) => p.toMap()).toList(),
    };
    final encoder = JsonEncoder.withIndent('  ', (nonEncodable) {
      if (nonEncodable is Timestamp) {
        return nonEncodable.toDate().toIso8601String();
      }
      if (nonEncodable is DateTime) {
        return nonEncodable.toIso8601String();
      }
      return nonEncodable.toString();
    });
    final fullJsonSnapshot = encoder.convert(fullSnapshotMap);

    return GoogleSheetsBackupBundle(
      generatedAt: DateTime.now(),
      spreadsheetUrl: spreadsheetUrl,
      totalCustomers: customers.length,
      totalServices: services.length,
      totalExpenses: expenses.length,
      totalInvoices: invoices.length,
      totalPayments: payments.length,
      vpsSheetRows: vpsRows,
      expenseSheetRows: expenseRows,
      invoiceSheetRows: invoiceRows,
      paymentSheetRows: paymentRows,
      vpsCsv: vpsCsv,
      vpsTsv: vpsTsv,
      expenseCsv: expenseCsv,
      expenseTsv: expenseTsv,
      invoiceCsv: invoiceCsv,
      invoiceTsv: invoiceTsv,
      paymentCsv: paymentCsv,
      paymentTsv: paymentTsv,
      fullJsonSnapshot: fullJsonSnapshot,
    );
  }

  /// Sends the backup payload directly to a Google Apps Script Web App Webhook
  Future<GoogleSheetsSyncResult> syncToWebhook({
    required String webhookUrl,
    required GoogleSheetsBackupBundle bundle,
  }) async {
    final cleanUrl = webhookUrl.trim();
    if (cleanUrl.isEmpty) {
      return GoogleSheetsSyncResult(
        success: false,
        message: 'URL Webhook Google Apps Script belum dikonfigurasikan.',
        timestamp: DateTime.now(),
      );
    }

    try {
      final uri = Uri.parse(cleanUrl);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bundle.toJsonPayload()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return GoogleSheetsSyncResult(
          success: true,
          message: 'Berhasil menyinkronkan seluruh data ke Google Spreadsheet via Webhook!',
          statusCode: response.statusCode,
          timestamp: DateTime.now(),
        );
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Handle Google Apps Script redirect if needed
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectResponse = await http.get(Uri.parse(redirectUrl));
          if (redirectResponse.statusCode == 200) {
            return GoogleSheetsSyncResult(
              success: true,
              message: 'Berhasil mencadangkan data ke Google Spreadsheet!',
              statusCode: 200,
              timestamp: DateTime.now(),
            );
          }
        }
      }

      return GoogleSheetsSyncResult(
        success: false,
        message: 'Webhook merespons dengan status: ${response.statusCode}',
        statusCode: response.statusCode,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return GoogleSheetsSyncResult(
        success: false,
        message: 'Gagal mengirim data ke Webhook: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Generates the ready-to-paste Google Apps Script code for 1-click cloud sync
  static String generateAppsScriptCode() {
    return '''/**
 * =========================================================================
 * GOOGLE APPS SCRIPT: FUCHUR AGENT DATABASE BACKUP & SYNC ENGINE
 * =========================================================================
 * Cara Pemasangan:
 * 1. Buka spreadsheet: https://docs.google.com/spreadsheets/d/1Rdcg6rgp4K7qBO328qeqHfzpaaYZjcRgvsI_OQGjLkE/edit
 * 2. Klik menu: Ekstensi (Extensions) -> Apps Script
 * 3. Hapus kode lama, paste seluruh kode di bawah ini, lalu simpan (Ctrl + S).
 * 4. Klik tombol "Deploy" (Terapkan) di kanan atas -> "New deployment" (Penerapan baru)
 * 5. Pilih jenis: "Web app" (Aplikasi web)
 *    - Execute as: "Me" (Saya)
 *    - Who has access: "Anyone" (Siapa saja)
 * 6. Klik "Deploy" -> Salin "Web App URL" yang dihasilkan.
 * 7. Buka Pengaturan di Fuchur Agent -> Tempelkan Web App URL tersebut untuk 1-Klik Sinkronisasi Otomatis!
 */

function doPost(e) {
  try {
    var rawData = e.postData.contents;
    var payload = JSON.parse(rawData);
    var ss = SpreadsheetApp.getActiveSpreadsheet();

    // 1. UPDATE SHEET VPS (Daftar Customer)
    if (payload.vpsRows && payload.vpsRows.length > 0) {
      var vpsSheet = ss.getSheetByName("VPS") || ss.getSheets()[0];
      // Bersihkan data lama mulai dari baris ke-8 ke bawah agar struktur header tetap terjaga
      var lastRow = vpsSheet.getLastRow();
      if (lastRow >= 8) {
        vpsSheet.getRange(8, 1, lastRow - 7, 13).clearContent();
      }
      
      // Ambil data tanpa baris header pertama
      var dataToInsert = payload.vpsRows.slice(1);
      if (dataToInsert.length > 0) {
        vpsSheet.getRange(8, 1, dataToInsert.length, dataToInsert[0].length).setValues(dataToInsert);
      }
    }

    // 2. UPDATE SHEET PENGELUARAN
    if (payload.expenseRows && payload.expenseRows.length > 0) {
      var expSheet = ss.getSheetByName("Pengeluaran");
      if (!expSheet) {
        expSheet = ss.insertSheet("Pengeluaran");
      }
      // Bersihkan data lama mulai dari baris ke-6 kolom B (kolom 2)
      var expLastRow = expSheet.getLastRow();
      if (expLastRow >= 6) {
        expSheet.getRange(6, 2, expLastRow - 5, 4).clearContent();
      }

      var expData = payload.expenseRows.slice(1);
      if (expData.length > 0) {
        expSheet.getRange(6, 2, expData.length, expData[0].length).setValues(expData);
      }
    }

    // 3. UPDATE SHEET TAGIHAN & PEMBAYARAN (Sheet3)
    if (payload.invoiceRows && payload.invoiceRows.length > 0) {
      var invSheet = ss.getSheetByName("Tagihan & Invoices");
      if (!invSheet) {
        invSheet = ss.getSheetByName("Sheet3") || ss.insertSheet("Tagihan & Invoices");
        invSheet.setName("Tagihan & Invoices");
      }
      invSheet.clear();
      invSheet.getRange(1, 1, payload.invoiceRows.length, payload.invoiceRows[0].length).setValues(payload.invoiceRows);
    }

    // 4. UPDATE SHEET RIWAYAT PEMBAYARAN
    if (payload.paymentRows && payload.paymentRows.length > 0) {
      var paySheet = ss.getSheetByName("Riwayat Pembayaran");
      if (!paySheet) {
        paySheet = ss.insertSheet("Riwayat Pembayaran");
      }
      paySheet.clear();
      paySheet.getRange(1, 1, payload.paymentRows.length, payload.paymentRows[0].length).setValues(payload.paymentRows);
    }

    return ContentService.createTextOutput(JSON.stringify({
      status: "success",
      message: "Data Firebase berhasil dicadangkan ke Google Spreadsheet!",
      timestamp: new Date().toISOString()
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doGet(e) {
  return ContentService.createTextOutput("Fuchur Agent Google Sheets Sync Webhook is Active!").setMimeType(ContentService.MimeType.TEXT);
}
''';
  }
}
