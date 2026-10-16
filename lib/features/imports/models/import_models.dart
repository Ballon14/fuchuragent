import '../../../core/constants/app_constants.dart';

class CsvCustomerRow {
  final int rowIndex;
  final String sourceId;
  final String phone;
  final String packageName;
  final String domain;
  final String optional;
  final String rawNominal;
  final int parsedNominal;
  final String paymentStatus;
  final String rawMulai;
  final DateTime? startDate;
  final String rawAkhir;
  final DateTime? endDate;
  final String worker;
  final bool workerPaid;
  final String rawStatus;
  final String normalizedStatus;
  final bool isValid;
  final bool isPlaceholder;
  bool isDuplicate;
  final List<String> validationErrors;

  CsvCustomerRow({
    required this.rowIndex,
    required this.sourceId,
    required this.phone,
    required this.packageName,
    required this.domain,
    required this.optional,
    required this.rawNominal,
    required this.parsedNominal,
    required this.paymentStatus,
    required this.rawMulai,
    this.startDate,
    required this.rawAkhir,
    this.endDate,
    required this.worker,
    required this.workerPaid,
    required this.rawStatus,
    required this.normalizedStatus,
    required this.isValid,
    required this.isPlaceholder,
    this.isDuplicate = false,
    required this.validationErrors,
  });

  factory CsvCustomerRow.fromRawList(int rowIndex, List<dynamic> row) {
    String getCell(int idx) {
      if (idx >= row.length) return '';
      return row[idx]?.toString().trim() ?? '';
    }

    final sourceId = getCell(1);
    final phone = getCell(2);
    final packageName = getCell(3);
    final domain = getCell(4);
    final optional = getCell(5);
    final rawNominal = getCell(6);
    final paymentStatus = getCell(7);
    final rawMulai = getCell(8);
    final rawAkhir = getCell(9);
    final worker = getCell(10);
    final rawWorkerPaid = getCell(11).toUpperCase();
    final workerPaid = rawWorkerPaid == 'TRUE' || rawWorkerPaid == '1';
    final rawStatus = getCell(12);

    final errors = <String>[];

    // Check if empty placeholder (e.g. rows 11-19 where only ID Customer exists and everything else is blank)
    final isPlaceholder = domain.isEmpty && phone.isEmpty && packageName.isEmpty && rawNominal.isEmpty;

    if (isPlaceholder) {
      errors.add('Data baris placeholder kosong.');
    }

    if (sourceId.isEmpty) {
      errors.add('ID Customer kosong.');
    }

    if (!isPlaceholder && domain.isEmpty) {
      errors.add('Domain wajib diisi.');
    }

    final parsedNominal = AppConstants.parseRupiah(rawNominal);
    if (!isPlaceholder && parsedNominal <= 0) {
      errors.add('Nominal harga tidak valid: "$rawNominal".');
    }

    final startDate = AppConstants.parseSpreadsheetDate(rawMulai);
    if (!isPlaceholder && startDate == null) {
      errors.add('Format tanggal mulai salah: "$rawMulai".');
    }

    final endDate = AppConstants.parseSpreadsheetDate(rawAkhir);
    if (!isPlaceholder && endDate == null) {
      errors.add('Format tanggal akhir salah: "$rawAkhir".');
    }

    // Normalize typo "Actice" -> "active", "Deactive" -> "deactive"
    String normalizedStatus = 'active';
    final lower = rawStatus.toLowerCase();
    if (lower == 'actice' || lower == 'active') {
      normalizedStatus = 'active';
    } else if (lower == 'deactive' || lower == 'inactive') {
      normalizedStatus = 'deactive';
    } else if (lower.isNotEmpty) {
      normalizedStatus = lower;
    }

    final isValid = errors.isEmpty && !isPlaceholder;

    return CsvCustomerRow(
      rowIndex: rowIndex,
      sourceId: sourceId,
      phone: phone,
      packageName: packageName.isNotEmpty ? packageName : 'Custom VPS',
      domain: domain,
      optional: optional,
      rawNominal: rawNominal,
      parsedNominal: parsedNominal,
      paymentStatus: paymentStatus,
      rawMulai: rawMulai,
      startDate: startDate,
      rawAkhir: rawAkhir,
      endDate: endDate,
      worker: worker,
      workerPaid: workerPaid,
      rawStatus: rawStatus,
      normalizedStatus: normalizedStatus,
      isValid: isValid,
      isPlaceholder: isPlaceholder,
      validationErrors: errors,
    );
  }
}

class ImportJobSummary {
  final int totalRows;
  final int validCount;
  final int placeholderCount;
  final int duplicateCount;
  final int errorCount;
  final int importedCount;

  ImportJobSummary({
    required this.totalRows,
    required this.validCount,
    required this.placeholderCount,
    required this.duplicateCount,
    required this.errorCount,
    this.importedCount = 0,
  });
}
