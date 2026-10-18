class GoogleSheetsBackupBundle {
  final DateTime generatedAt;
  final String spreadsheetUrl;
  final int totalCustomers;
  final int totalServices;
  final int totalExpenses;
  final int totalInvoices;
  final int totalPayments;

  // Formatted sheet data
  final List<List<dynamic>> vpsSheetRows;
  final List<List<dynamic>> expenseSheetRows;
  final List<List<dynamic>> invoiceSheetRows;
  final List<List<dynamic>> paymentSheetRows;

  // Exportable strings
  final String vpsCsv;
  final String vpsTsv;
  final String expenseCsv;
  final String expenseTsv;
  final String invoiceCsv;
  final String invoiceTsv;
  final String paymentCsv;
  final String paymentTsv;
  final String fullJsonSnapshot;

  const GoogleSheetsBackupBundle({
    required this.generatedAt,
    required this.spreadsheetUrl,
    required this.totalCustomers,
    required this.totalServices,
    required this.totalExpenses,
    required this.totalInvoices,
    required this.totalPayments,
    required this.vpsSheetRows,
    required this.expenseSheetRows,
    required this.invoiceSheetRows,
    required this.paymentSheetRows,
    required this.vpsCsv,
    required this.vpsTsv,
    required this.expenseCsv,
    required this.expenseTsv,
    required this.invoiceCsv,
    required this.invoiceTsv,
    required this.paymentCsv,
    required this.paymentTsv,
    required this.fullJsonSnapshot,
  });

  Map<String, dynamic> toJsonPayload() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'spreadsheetUrl': spreadsheetUrl,
      'counts': {
        'customers': totalCustomers,
        'services': totalServices,
        'expenses': totalExpenses,
        'invoices': totalInvoices,
        'payments': totalPayments,
      },
      'vpsRows': vpsSheetRows,
      'expenseRows': expenseSheetRows,
      'invoiceRows': invoiceSheetRows,
      'paymentRows': paymentSheetRows,
      'fullSnapshot': fullJsonSnapshot,
    };
  }
}

class GoogleSheetsSyncResult {
  final bool success;
  final String message;
  final int? statusCode;
  final DateTime timestamp;

  const GoogleSheetsSyncResult({
    required this.success,
    required this.message,
    this.statusCode,
    required this.timestamp,
  });
}
