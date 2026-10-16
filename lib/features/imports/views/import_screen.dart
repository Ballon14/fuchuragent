import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/import_models.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _urlCtrl = TextEditingController(
    text: 'https://docs.google.com/spreadsheets/d/e/2PACX-1vT1izWzmNR3gtNR7XkZt7RPe6uWeHO4CHuMnyJvTP_5ucGg0XXp6hKH4niTkUIDoT4QvpotNT2SbkKj/pubhtml?gid=0&single=true',
  );

  List<CsvCustomerRow>? _parsedRows;
  bool _isLoading = false;
  String? _errorMessage;
  int _importProgress = 0;
  int _importTotal = 0;
  ImportJobSummary? _importSummary;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  // Load from Live Google Sheets URL
  Future<void> _loadFromUrl() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parsedRows = null;
      _importSummary = null;
    });

    try {
      final repo = ref.read(importRepositoryProvider);
      final csvString = await repo.fetchCsvFromUrl(_urlCtrl.text.trim());
      final rows = await repo.parseCsv(csvString);
      setState(() => _parsedRows = rows);
    } catch (e) {
      setState(() => _errorMessage = 'Gagal memuat dari URL: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Load from Local CSV File
  Future<void> _pickLocalFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (files.isNotEmpty) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _parsedRows = null;
          _importSummary = null;
        });

        final file = files.first;
        final csvString = await file.xFile.readAsString();

        if (csvString.isNotEmpty) {
          final repo = ref.read(importRepositoryProvider);
          final rows = await repo.parseCsv(csvString);
          setState(() => _parsedRows = rows);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Gagal membaca file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Load from Bundled sample asset
  Future<void> _loadBundledSample() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parsedRows = null;
      _importSummary = null;
    });

    try {
      final csvString = await rootBundle.loadString('assets/data/customer_source.csv');
      final repo = ref.read(importRepositoryProvider);
      final rows = await repo.parseCsv(csvString);
      setState(() => _parsedRows = rows);
    } catch (e) {
      setState(() => _errorMessage = 'Gagal memuat data bundled: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Execute Batch Write to Firestore
  Future<void> _executeImport() async {
    if (_parsedRows == null || _parsedRows!.isEmpty) return;

    final validRows = _parsedRows!.where((r) => r.isValid && !r.isPlaceholder).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data valid yang dapat diimpor.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _importProgress = 0;
      _importTotal = validRows.length;
    });

    try {
      final repo = ref.read(importRepositoryProvider);
      final summary = await repo.executeImport(
        rowsToImport: _parsedRows!,
        onProgress: (current, total) {
          setState(() {
            _importProgress = current;
            _importTotal = total;
          });
        },
      );

      ref.invalidate(dashboardStatsProvider);
      setState(() {
        _importSummary = summary;
        _parsedRows = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil mengimpor ${summary.importedCount} pelanggan dan layanan VPS!')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Gagal mengimpor ke Firestore: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impor Data Pelanggan Google Sheets')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions & Source Input
            AppCard(
              title: 'Sumber Data Spreadsheet Pelanggan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih salah satu metode untuk mengimpor data pelanggan, layanan VPS, dan status pembayaran:',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'URL Google Sheets (Publik / Web Publish)',
                      prefixIcon: const Icon(Icons.link_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.download_rounded, color: AppColors.cyan),
                        tooltip: 'Tarik dari URL',
                        onPressed: _isLoading ? null : _loadFromUrl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                        label: const Text('Tarik dari Google Sheets Live'),
                        onPressed: _isLoading ? null : _loadFromUrl,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: const Text('Pilih File CSV Lokal'),
                        onPressed: _isLoading ? null : _pickLocalFile,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.dataset_rounded, size: 18, color: AppColors.cyan),
                        label: const Text('Gunakan Data Sampel FuchurHost (customer_source.csv)'),
                        onPressed: _isLoading ? null : _loadBundledSample,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger))),
                  ],
                ),
              ),
            ],

            if (_isLoading) ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.cyan),
                    const SizedBox(height: 16),
                    Text(
                      _importTotal > 0
                          ? 'Menyimpan data ke Firestore... ($_importProgress / $_importTotal)'
                          : 'Memproses dan memvalidasi baris spreadsheet...',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],

            // Import Success Summary Card
            if (_importSummary != null) ...[
              const SizedBox(height: 24),
              _buildSummaryCard(_importSummary!),
            ],

            // Preview Table & Confirmation Action
            if (_parsedRows != null) ...[
              const SizedBox(height: 24),
              _buildPreviewSection(_parsedRows!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ImportJobSummary summary) {
    return AppCard(
      title: 'Hasil Eksekusi Impor Data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
              const SizedBox(width: 12),
              Text(
                '${summary.importedCount} Data Berhasil Disimpan ke Cloud Firestore',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildSummaryStat('Total Baris', '${summary.totalRows}'),
              _buildSummaryStat('Baris Valid', '${summary.validCount}', color: AppColors.success),
              _buildSummaryStat('Placeholder Kosong', '${summary.placeholderCount}', color: Colors.white54),
              _buildSummaryStat('Data Duplikat', '${summary.duplicateCount}', color: AppColors.warning),
              _buildSummaryStat('Baris Error', '${summary.errorCount}', color: AppColors.danger),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Catatan: Baris placeholder kosong (Cus-011 s/d Cus-019) secara otomatis dilewati demi integritas data.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? Colors.white)),
      ],
    );
  }

  Widget _buildPreviewSection(List<CsvCustomerRow> rows) {
    final validCount = rows.where((r) => r.isValid && !r.isPlaceholder).length;
    final placeholderCount = rows.where((r) => r.isPlaceholder).length;
    final duplicateCount = rows.where((r) => r.isDuplicate).length;

    return AppCard(
      title: 'Pratinjau Data & Validasi Pemetaan Kolom (${rows.length} Baris)',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () => setState(() => _parsedRows = null),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload_rounded, size: 16),
            label: Text('Simpan ke Firestore ($validCount Data)'),
            onPressed: validCount == 0 ? null : _executeImport,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLightDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Siap diimpor: $validCount baris valid | $placeholderCount baris placeholder kosong terdeteksi | $duplicateCount potensi duplikat',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Baris')),
                DataColumn(label: Text('ID Sumber')),
                DataColumn(label: Text('Nomor HP')),
                DataColumn(label: Text('Domain')),
                DataColumn(label: Text('Paket')),
                DataColumn(label: Text('Nominal')),
                DataColumn(label: Text('Pembayaran')),
                DataColumn(label: Text('Mulai - Akhir')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Validasi')),
              ],
              rows: rows.map((r) {
                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (r.isPlaceholder) return Colors.grey.withValues(alpha: 0.05);
                    if (r.isDuplicate) return AppColors.warning.withValues(alpha: 0.1);
                    if (!r.isValid) return AppColors.danger.withValues(alpha: 0.1);
                    return null;
                  }),
                  cells: [
                    DataCell(Text('#${r.rowIndex}')),
                    DataCell(Text(r.sourceId.isNotEmpty ? r.sourceId : '-')),
                    DataCell(Text(r.phone.isNotEmpty ? r.phone : '-')),
                    DataCell(Text(r.domain.isNotEmpty ? r.domain : '-')),
                    DataCell(Text(r.packageName.isNotEmpty ? r.packageName : '-')),
                    DataCell(Text(r.parsedNominal > 0 ? AppConstants.formatRupiah(r.parsedNominal) : '-')),
                    DataCell(Text(r.paymentStatus.isNotEmpty ? r.paymentStatus : '-')),
                    DataCell(Text('${r.rawMulai} - ${r.rawAkhir}')),
                    DataCell(StatusBadge(status: r.normalizedStatus, label: r.rawStatus)),
                    DataCell(
                      r.isPlaceholder
                          ? const Text('Placeholder Kosong', style: TextStyle(fontSize: 11, color: Colors.white38))
                          : (r.isDuplicate
                              ? const Text('Potensi Duplikat', style: TextStyle(fontSize: 11, color: AppColors.warning))
                              : (r.isValid
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18)
                                  : Text(r.validationErrors.join(', '), style: const TextStyle(fontSize: 11, color: AppColors.danger)))),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
