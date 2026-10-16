import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/import_models.dart';

class ImportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Fetch CSV from Live Google Sheets URL
  Future<String> fetchCsvFromUrl(String url) async {
    String csvUrl = url.trim();
    if (csvUrl.contains('/pubhtml')) {
      csvUrl = csvUrl.replaceAll('/pubhtml', '/pub');
      if (!csvUrl.contains('output=csv')) {
        csvUrl += csvUrl.contains('?') ? '&output=csv' : '?output=csv';
      }
    }

    final response = await http.get(Uri.parse(csvUrl));
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh spreadsheet dari URL (Status: ${response.statusCode})');
    }
    return response.body;
  }

  // 2. Parse CSV String into List of CsvCustomerRow
  Future<List<CsvCustomerRow>> parseCsv(String csvContent) async {
    final rawRows = csv.decode(csvContent);

    // Find the header row (look for "ID Customer" or "Nomor HP")
    int headerIndex = -1;
    for (int i = 0; i < rawRows.length; i++) {
      final rowStr = rawRows[i].join(',').toLowerCase();
      if (rowStr.contains('id customer') || rowStr.contains('nomor hp') || rowStr.contains('domain')) {
        headerIndex = i;
        break;
      }
    }

    if (headerIndex == -1) {
      throw Exception('Header tabel tidak ditemukan dalam file CSV.');
    }

    // Existing IDs in Firestore for duplicate detection
    final existingCustomersSnap = await _firestore.collection('customers').get();
    final existingSourceIds = existingCustomersSnap.docs
        .map((d) => (d.data()['sourceId'] as String? ?? '').toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    final existingServicesSnap = await _firestore.collection('vps_services').get();
    final existingDomains = existingServicesSnap.docs
        .map((d) => (d.data()['domain'] as String? ?? '').toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();

    final parsedRows = <CsvCustomerRow>[];

    for (int i = headerIndex + 1; i < rawRows.length; i++) {
      final row = rawRows[i];
      if (row.isEmpty || row.every((c) => c == null || c.toString().trim().isEmpty)) {
        continue;
      }

      final parsed = CsvCustomerRow.fromRawList(i + 1, row);

      // Check duplicate against existing Firestore database
      if (!parsed.isPlaceholder) {
        if (existingSourceIds.contains(parsed.sourceId.toLowerCase()) ||
            existingDomains.contains(parsed.domain.toLowerCase())) {
          parsed.isDuplicate = true;
        }
      }

      parsedRows.add(parsed);
    }

    return parsedRows;
  }

  // 3. Execute Batch Import with Progress Reporting
  Future<ImportJobSummary> executeImport({
    required List<CsvCustomerRow> rowsToImport,
    Function(int current, int total)? onProgress,
  }) async {
    final validRows = rowsToImport.where((r) => r.isValid && !r.isPlaceholder).toList();
    final total = validRows.length;

    int importedCount = 0;
    const batchSize = 100;

    for (int i = 0; i < validRows.length; i += batchSize) {
      final chunk = validRows.sublist(i, (i + batchSize > validRows.length) ? validRows.length : i + batchSize);
      final batch = _firestore.batch();

      for (final row in chunk) {
        // Customer Document
        final customerRef = _firestore.collection('customers').doc();
        final customerName = 'Customer ${row.sourceId}';

        batch.set(customerRef, {
          'sourceId': row.sourceId,
          'name': customerName,
          'phone': row.phone,
          'status': row.normalizedStatus == 'active' ? 'active' : 'inactive',
          'notes': 'Diimpor dari Google Sheets (${row.rawStatus})',
          'createdAt': row.startDate != null ? Timestamp.fromDate(row.startDate!) : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Service Document
        final serviceRef = _firestore.collection('vps_services').doc();
        batch.set(serviceRef, {
          'customerId': customerRef.id,
          'serviceName': 'VPS ${row.domain.replaceAll('https://', '').replaceAll('http://', '')}',
          'domain': row.domain,
          'packageName': row.packageName,
          'vcpu': 1,
          'ramGb': 1,
          'storageGb': 20,
          'price': row.parsedNominal,
          'startDate': row.startDate != null ? Timestamp.fromDate(row.startDate!) : null,
          'endDate': row.endDate != null ? Timestamp.fromDate(row.endDate!) : null,
          'status': row.normalizedStatus,
          'deploymentType': row.optional.isNotEmpty ? row.optional : 'Publish',
          'worker': row.worker.isNotEmpty ? row.worker : null,
          'workerPaid': row.workerPaid,
          'notes': 'Impor Spreadsheet',
          'createdAt': row.startDate != null ? Timestamp.fromDate(row.startDate!) : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Invoice Document
        final invoiceRef = _firestore.collection('invoices').doc();
        final isPaid = row.paymentStatus.toLowerCase() == 'lunas';
        final nowStr = '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}';
        final invNum = 'INV-$nowStr-${(importedCount + 1).toString().padLeft(4, '0')}';

        batch.set(invoiceRef, {
          'invoiceNumber': invNum,
          'customerId': customerRef.id,
          'serviceId': serviceRef.id,
          'items': [
            {
              'description': 'Layanan VPS (${row.packageName}) - ${row.domain}',
              'unitPrice': row.parsedNominal,
              'quantity': 1,
              'total': row.parsedNominal,
            }
          ],
          'subtotal': row.parsedNominal,
          'discount': 0,
          'total': row.parsedNominal,
          'paidAmount': isPaid ? row.parsedNominal : 0,
          'status': isPaid ? 'paid' : 'unpaid',
          'issuedAt': row.startDate != null ? Timestamp.fromDate(row.startDate!) : FieldValue.serverTimestamp(),
          'dueDate': row.endDate != null ? Timestamp.fromDate(row.endDate!) : FieldValue.serverTimestamp(),
          'notes': 'Tagihan Impor Awal',
          'createdBy': _auth.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // If paid, create payment record
        if (isPaid) {
          final paymentRef = _firestore.collection('payments').doc();
          batch.set(paymentRef, {
            'invoiceId': invoiceRef.id,
            'customerId': customerRef.id,
            'serviceId': serviceRef.id,
            'amount': row.parsedNominal,
            'paymentDate': row.startDate != null ? Timestamp.fromDate(row.startDate!) : FieldValue.serverTimestamp(),
            'paymentMethod': 'Transfer Bank (Lunas Spreadsheet)',
            'referenceNumber': 'SHEET-${row.sourceId}',
            'recordedBy': _auth.currentUser?.uid,
            'notes': 'Status pembayaran lunas diimpor dari Google Sheets',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        importedCount++;
      }

      await batch.commit();
      onProgress?.call(importedCount, total);
    }

    // Record Import Job in Firestore
    await _firestore.collection('import_jobs').add({
      'totalRows': rowsToImport.length,
      'validCount': validRows.length,
      'importedCount': importedCount,
      'importedBy': _auth.currentUser?.uid,
      'importerEmail': _auth.currentUser?.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'IMPORT_SHEET_DATA',
      'category': 'IMPORT',
      'details': 'Impor data spreadsheet selesai: $importedCount pelanggan & layanan VPS berhasil disimpan.',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return ImportJobSummary(
      totalRows: rowsToImport.length,
      validCount: validRows.length,
      placeholderCount: rowsToImport.where((r) => r.isPlaceholder).length,
      duplicateCount: rowsToImport.where((r) => r.isDuplicate).length,
      errorCount: rowsToImport.where((r) => !r.isValid && !r.isPlaceholder).length,
      importedCount: importedCount,
    );
  }
}
