import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../models/google_sheets_backup_model.dart';
import '../services/google_sheets_backup_service.dart';

class GoogleSheetsBackupDialog extends StatefulWidget {
  final String initialSpreadsheetUrl;
  final String initialWebhookUrl;
  final ValueChanged<String>? onWebhookSaved;

  const GoogleSheetsBackupDialog({
    super.key,
    required this.initialSpreadsheetUrl,
    required this.initialWebhookUrl,
    this.onWebhookSaved,
  });

  @override
  State<GoogleSheetsBackupDialog> createState() => _GoogleSheetsBackupDialogState();
}

class _GoogleSheetsBackupDialogState extends State<GoogleSheetsBackupDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GoogleSheetsBackupService _backupService = GoogleSheetsBackupService();

  late TextEditingController _webhookUrlCtrl;
  bool _isLoading = true;
  String? _errorMessage;
  GoogleSheetsBackupBundle? _bundle;

  // Webhook sync state
  bool _isSyncingWebhook = false;
  GoogleSheetsSyncResult? _lastSyncResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _webhookUrlCtrl = TextEditingController(text: widget.initialWebhookUrl);
    _loadBackupBundle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _webhookUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBackupBundle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bundle = await _backupService.prepareBackupFromFirestore(
        spreadsheetUrl: widget.initialSpreadsheetUrl,
      );
      if (mounted) {
        setState(() {
          _bundle = bundle;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openSpreadsheetInBrowser() async {
    try {
      final uri = Uri.parse(widget.initialSpreadsheetUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka URL: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _executeWebhookSync() async {
    final webhook = _webhookUrlCtrl.text.trim();
    if (webhook.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan Web App URL Google Apps Script terlebih dahulu.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_bundle == null) return;

    setState(() {
      _isSyncingWebhook = true;
      _lastSyncResult = null;
    });

    try {
      final result = await _backupService.syncToWebhook(
        webhookUrl: webhook,
        bundle: _bundle!,
      );

      if (mounted) {
        setState(() {
          _lastSyncResult = result;
          _isSyncingWebhook = false;
        });

        if (result.success) {
          widget.onWebhookSaved?.call(webhook);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result.message)),
                ],
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncingWebhook = false;
          _lastSyncResult = GoogleSheetsSyncResult(
            success: false,
            message: 'Terjadi kesalahan: $e',
            timestamp: DateTime.now(),
          );
        });
      }
    }
  }

  void _copyToClipboard(String text, String successNotice) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(successNotice)),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 16,
        vertical: isDesktop ? 32 : 20,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Color(0xFF0F9D58), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cadangan & Sinkronisasi Google Spreadsheet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Sinkronkan data Firebase Firestore langsung ke target Google Sheets',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: _openSpreadsheetInBrowser,
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('Buka Sheet'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Tutup',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFF0F9D58),
                labelColor: const Color(0xFF0F9D58),
                unselectedLabelColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.dns_rounded, size: 16),
                    text: 'VPS (${_bundle?.totalServices ?? 0})',
                  ),
                  Tab(
                    icon: const Icon(Icons.money_off_csred_rounded, size: 16),
                    text: 'Pengeluaran (${_bundle?.totalExpenses ?? 0})',
                  ),
                  Tab(
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    text: 'Tagihan (${_bundle?.totalInvoices ?? 0})',
                  ),
                  Tab(
                    icon: const Icon(Icons.payments_rounded, size: 16),
                    text: 'Riwayat Bayar (${_bundle?.totalPayments ?? 0})',
                  ),
                  const Tab(
                    icon: Icon(Icons.cloud_sync_rounded, size: 16),
                    text: 'Otomasi Apps Script',
                  ),
                ],
              ),
            ),
            body: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0F9D58)),
                        SizedBox(height: 16),
                        Text('Mengekstrak seluruh data dari Cloud Firestore...'),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                              const SizedBox(height: 12),
                              Text('Gagal memuat data: $_errorMessage', textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadBackupBundle,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildVpsTab(isDark, primaryAccent),
                          _buildExpenseTab(isDark, primaryAccent),
                          _buildInvoiceTab(isDark, primaryAccent),
                          _buildPaymentTab(isDark, primaryAccent),
                          _buildAppsScriptTab(isDark, primaryAccent),
                        ],
                      ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Target Sheet: ${_bundle?.spreadsheetUrl ?? widget.initialSpreadsheetUrl}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Selesai'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: SHEET VPS
  // ===========================================================================
  Widget _buildVpsTab(bool isDark, Color primaryAccent) {
    final bundle = _bundle;
    if (bundle == null) return const SizedBox.shrink();

    // Generate TSV without the header for direct paste into cell A8
    final dataRowsOnly = bundle.vpsSheetRows.skip(1).toList();
    final dataOnlyTsv = GoogleSheetsBackupService.convertToTsv(dataRowsOnly);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            title: 'Sheet 1: "VPS" (Daftar Customer VPS)',
            subtitle:
                'Struktur kolom: No, ID Customer, Nomor HP, Paket, Domain, Optional, Nominal, Payment Status, Mulai, Akhir, Worker, Payment Worker, Status. Siap dipaste mulai baris ke-8 (Cell A8).',
            icon: Icons.dns_rounded,
            color: const Color(0xFF0F9D58),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9D58),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.content_paste_go_rounded, size: 18),
                  label: const Text(
                    'Salin Data Sel VPS (Siap Paste Cell A8)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _copyToClipboard(
                      dataOnlyTsv,
                      'Data VPS (${dataRowsOnly.length} baris) disalin! Buka Sheet VPS dan tekan Ctrl+V di Cell A8.',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Salin Seluruh CSV'),
                onPressed: () {
                  _copyToClipboard(
                    bundle.vpsCsv,
                    'CSV Sheet VPS berhasil disalin ke clipboard!',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Pratinjau Data VPS (${bundle.vpsSheetRows.length} baris total):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildTablePreview(bundle.vpsSheetRows, isDark),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SHEET PENGELUARAN
  // ===========================================================================
  Widget _buildExpenseTab(bool isDark, Color primaryAccent) {
    final bundle = _bundle;
    if (bundle == null) return const SizedBox.shrink();

    final dataRowsOnly = bundle.expenseSheetRows.skip(1).toList();
    final dataOnlyTsv = GoogleSheetsBackupService.convertToTsv(dataRowsOnly);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            title: 'Sheet 2: "Pengeluaran"',
            subtitle:
                'Struktur kolom: No, Nama, Total, Tanggal. Sesuai template Google Sheets Pengeluaran mulai baris ke-6 kolom B (Cell B6).',
            icon: Icons.money_off_csred_rounded,
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.content_paste_go_rounded, size: 18),
                  label: const Text(
                    'Salin Data Sel Pengeluaran (Siap Paste Cell B6)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _copyToClipboard(
                      dataOnlyTsv,
                      'Data Pengeluaran (${dataRowsOnly.length} baris) disalin! Buka Sheet Pengeluaran dan paste di Cell B6.',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Salin CSV'),
                onPressed: () {
                  _copyToClipboard(
                    bundle.expenseCsv,
                    'CSV Sheet Pengeluaran berhasil disalin ke clipboard!',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Pratinjau Data Pengeluaran (${bundle.expenseSheetRows.length} baris):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildTablePreview(bundle.expenseSheetRows, isDark),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: SHEET TAGIHAN & INVOICES
  // ===========================================================================
  Widget _buildInvoiceTab(bool isDark, Color primaryAccent) {
    final bundle = _bundle;
    if (bundle == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            title: 'Sheet 3: "Tagihan & Invoices"',
            subtitle:
                'Struktur kolom: No, Nomor Invoice, ID Customer, Nama Pelanggan, Subtotal, Diskon, Total Tagihan, Terbayar, Status, Jatuh Tempo, Catatan.',
            icon: Icons.receipt_long_rounded,
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.content_paste_go_rounded, size: 18),
                  label: const Text(
                    'Salin Seluruh Tabel Tagihan (TSV)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _copyToClipboard(
                      bundle.invoiceTsv,
                      'Data Tagihan & Invoices disalin! Buat sheet baru / Sheet3 lalu paste di Cell A1.',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Salin CSV'),
                onPressed: () {
                  _copyToClipboard(
                    bundle.invoiceCsv,
                    'CSV Tagihan berhasil disalin ke clipboard!',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Pratinjau Data Tagihan (${bundle.invoiceSheetRows.length} baris):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildTablePreview(bundle.invoiceSheetRows, isDark),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: SHEET RIWAYAT PEMBAYARAN
  // ===========================================================================
  Widget _buildPaymentTab(bool isDark, Color primaryAccent) {
    final bundle = _bundle;
    if (bundle == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            title: 'Sheet 4: "Riwayat Pembayaran"',
            subtitle:
                'Struktur kolom: No, ID Pembayaran, Nomor Invoice, Nama Pelanggan, Nominal (Rp), Metode Pembayaran, No Referensi, Tanggal Bayar, Catatan.',
            icon: Icons.payments_rounded,
            color: AppColors.electricBlue,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electricBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.content_paste_go_rounded, size: 18),
                  label: const Text(
                    'Salin Seluruh Tabel Pembayaran (TSV)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _copyToClipboard(
                      bundle.paymentTsv,
                      'Data Riwayat Pembayaran disalin! Buka Google Sheets dan paste di Cell A1.',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Salin CSV'),
                onPressed: () {
                  _copyToClipboard(
                    bundle.paymentCsv,
                    'CSV Riwayat Pembayaran berhasil disalin ke clipboard!',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Pratinjau Data Riwayat Pembayaran (${bundle.paymentSheetRows.length} baris):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildTablePreview(bundle.paymentSheetRows, isDark),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 5: OTOMASI APPS SCRIPT
  // ===========================================================================
  Widget _buildAppsScriptTab(bool isDark, Color primaryAccent) {
    final scriptCode = GoogleSheetsBackupService.generateAppsScriptCode();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(
            title: 'Sinkronisasi Otomatis 1-Klik Cloud (Google Apps Script)',
            subtitle:
                'Anda dapat menghubungkan Fuchur Agent langsung ke Google Spreadsheet sehingga setiap backup otomatis mengisi dan memperbarui seluruh baris sheet tanpa perlu copy-paste manual.',
            icon: Icons.cloud_sync_rounded,
            color: const Color(0xFF0F9D58),
          ),
          const SizedBox(height: 16),

          // Webhook Runner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D2A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Koneksi Webhook Google Apps Script',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masukkan URL Web App hasil deploy Apps Script Anda:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _webhookUrlCtrl,
                        decoration: const InputDecoration(
                          hintText: 'https://script.google.com/macros/s/.../exec',
                          prefixIcon: Icon(Icons.link_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      ),
                      onPressed: _isSyncingWebhook ? null : _executeWebhookSync,
                      icon: _isSyncingWebhook
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_isSyncingWebhook ? 'Menyinkronkan...' : 'Sinkronkan Sekarang'),
                    ),
                  ],
                ),
                if (_lastSyncResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _lastSyncResult!.success
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _lastSyncResult!.success
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.danger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _lastSyncResult!.success
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _lastSyncResult!.success ? AppColors.success : AppColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastSyncResult!.message,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _lastSyncResult!.success ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Code Container with Copy Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kode Google Apps Script (Siap Pakai):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Salin Seluruh Kode Script'),
                onPressed: () {
                  _copyToClipboard(
                    scriptCode,
                    'Kode Google Apps Script berhasil disalin ke clipboard!',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 240,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0F17) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                scriptCode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Panduan Pemasangan Cepat:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildStepItem('1', 'Buka Google Spreadsheet target Anda.'),
          _buildStepItem('2', 'Buka menu Extensions (Ekstensi) > Apps Script.'),
          _buildStepItem('3', 'Hapus semua kode bawaan, tempelkan (Paste) kode di atas, lalu tekan Simpan (Ctrl+S).'),
          _buildStepItem('4', 'Klik Deploy (Terapkan) di pojok kanan atas > New deployment (Penerapan baru).'),
          _buildStepItem('5', 'Pilih tipe "Web app", set Execute as "Me", dan Who has access "Anyone".'),
          _buildStepItem('6', 'Salin URL Web App yang muncul, tempelkan di kotak di atas, dan klik "Sinkronkan Sekarang".'),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================
  Widget _buildInfoBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String instruction) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0F9D58).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F9D58),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              instruction,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablePreview(List<List<dynamic>> rows, bool isDark) {
    if (rows.isEmpty) {
      return const Center(child: Text('Tidak ada data'));
    }

    final headers = rows.first;
    final dataRows = rows.skip(1).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B111A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 38,
            horizontalMargin: 12,
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF131D2A) : const Color(0xFFF1F5F9),
            ),
            columns: headers
                .map(
                  (h) => DataColumn(
                    label: Text(
                      h.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            rows: dataRows
                .take(15)
                .map(
                  (row) => DataRow(
                    cells: row
                        .map(
                          (c) => DataCell(
                            Text(
                              c?.toString() ?? '',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
