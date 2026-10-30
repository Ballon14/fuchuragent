import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../dashboard/models/dashboard_stats.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan & Rekapitulasi Operasional'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.cyan : const Color(0xFF0284C7),
          ),
        ),
        error: (err, _) => Center(child: Text('Gagal memuat laporan: $err')),
        data: (stats) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rekapitulasi Kinerja Bisnis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zona Waktu: Asia/Jakarta • Mata Uang: IDR (Rupiah)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),

                // Financial Summary Card
                AppCard(
                  title: 'Ringkasan Keuangan & Tagihan',
                  child: Column(
                    children: [
                      _buildReportRow(
                        context,
                        'Total Pendapatan Diterima (Kas Masuk Aktual)',
                        AppConstants.formatRupiah(stats.totalRevenue),
                        color: isDark ? AppColors.success : const Color(0xFF047857),
                        isBold: true,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Total Pengeluaran Operasional (Kas Keluar)',
                        AppConstants.formatRupiah(stats.totalExpenses),
                        color: isDark ? AppColors.danger : const Color(0xFFDC2626),
                        isBold: true,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Laba Bersih Operasional (Net Profit)',
                        AppConstants.formatRupiah(stats.netProfit),
                        color: stats.netProfit >= 0
                            ? (isDark ? AppColors.cyan : const Color(0xFF0284C7))
                            : (isDark ? AppColors.danger : const Color(0xFFDC2626)),
                        isBold: true,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Total Piutang / Tagihan Belum Dibayar',
                        AppConstants.formatRupiah(stats.unpaidAmount),
                        color: isDark ? AppColors.warning : const Color(0xFFB45309),
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Jumlah Tagihan Terbuka',
                        '${stats.unpaidInvoicesCount} Tagihan',
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Jumlah Tagihan Melewati Jatuh Tempo (Overdue)',
                        '${stats.overdueInvoicesCount} Tagihan',
                        color: stats.overdueInvoicesCount > 0 ? (isDark ? AppColors.danger : const Color(0xFFB91C1C)) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Services & Customer Summary Card
                AppCard(
                  title: 'Ringkasan Layanan VPS & Pelanggan',
                  child: Column(
                    children: [
                      _buildReportRow(
                        context,
                        'Total Pelanggan Terdaftar',
                        '${stats.totalCustomers} Pelanggan',
                        isBold: true,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Pelanggan Aktif',
                        '${stats.activeCustomers} Pelanggan',
                        color: primaryAccent,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Total Instance Layanan VPS',
                        '${stats.totalServices} Layanan',
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Layanan VPS Aktif',
                        '${stats.activeServices} Instance',
                        color: primaryAccent,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Layanan Mendekati Jatuh Tempo (≤ 7 Hari)',
                        '${stats.expiringServicesCount} Instance',
                        color: isDark ? AppColors.warning : const Color(0xFFB45309),
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        context,
                        'Layanan Telah Kedaluwarsa',
                        '${stats.expiredServicesCount} Instance',
                        color: isDark ? AppColors.danger : const Color(0xFFB91C1C),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Export Options Card
                AppCard(
                  title: 'Ekspor Data Laporan',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unduh data rekapitulasi untuk keperluan pembukuan atau audit:',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.table_view_rounded, size: 16),
                            label: const Text('Ekspor Rekap CSV'),
                            onPressed: () => _exportCsv(context, stats),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Salin Ringkasan Teks'),
                            onPressed: () async {
                              final textSummary = '''
Laporan Ringkasan Operasional & Keuangan (${AppConstants.formatDate(DateTime.now())}):
1. Keuangan:
- Pendapatan Kas Masuk: ${AppConstants.formatRupiah(stats.totalRevenue)}
- Pengeluaran Kas Keluar: ${AppConstants.formatRupiah(stats.totalExpenses)}
- Laba Bersih Operasional: ${AppConstants.formatRupiah(stats.netProfit)}
- Total Piutang Terbuka: ${AppConstants.formatRupiah(stats.unpaidAmount)} (${stats.unpaidInvoicesCount} tagihan)
- Tagihan Overdue: ${stats.overdueInvoicesCount} tagihan

2. Layanan & Pelanggan:
- Total Pelanggan: ${stats.totalCustomers} (${stats.activeCustomers} aktif)
- Total Layanan VPS: ${stats.totalServices} (${stats.activeServices} aktif)
- Layanan Mendekati Jatuh Tempo: ${stats.expiringServicesCount} instance
- Layanan Kedaluwarsa: ${stats.expiredServicesCount} instance
'''.trim();
                              await Clipboard.setData(ClipboardData(text: textSummary));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ringkasan laporan berhasil disalin ke clipboard!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _exportCsv(BuildContext context, DashboardStats stats) {
    final rows = [
      ['Laporan Rekapitulasi Operasional & Keuangan'],
      ['Tanggal Ekspor', DateTime.now().toIso8601String()],
      [],
      ['Kategori', 'Indikator', 'Nilai Angka', 'Format Tampilan'],
      ['Keuangan', 'Total Pendapatan Kas Masuk', stats.totalRevenue, AppConstants.formatRupiah(stats.totalRevenue)],
      ['Keuangan', 'Total Pengeluaran Kas Keluar', stats.totalExpenses, AppConstants.formatRupiah(stats.totalExpenses)],
      ['Keuangan', 'Laba Bersih Operasional (Net Profit)', stats.netProfit, AppConstants.formatRupiah(stats.netProfit)],
      ['Keuangan', 'Total Piutang Tagihan Terbuka', stats.unpaidAmount, AppConstants.formatRupiah(stats.unpaidAmount)],
      ['Keuangan', 'Jumlah Tagihan Belum Lunas', stats.unpaidInvoicesCount, '${stats.unpaidInvoicesCount} Tagihan'],
      ['Keuangan', 'Jumlah Tagihan Overdue', stats.overdueInvoicesCount, '${stats.overdueInvoicesCount} Tagihan'],
      [],
      ['Operasional', 'Total Pelanggan Terdaftar', stats.totalCustomers, '${stats.totalCustomers} Pelanggan'],
      ['Operasional', 'Pelanggan Aktif', stats.activeCustomers, '${stats.activeCustomers} Pelanggan'],
      ['Operasional', 'Total Layanan VPS', stats.totalServices, '${stats.totalServices} Layanan'],
      ['Operasional', 'Layanan VPS Aktif', stats.activeServices, '${stats.activeServices} Instance'],
      ['Operasional', 'Layanan Mendekati Jatuh Tempo (<= 7 hari)', stats.expiringServicesCount, '${stats.expiringServicesCount} Instance'],
      ['Operasional', 'Layanan Kedaluwarsa', stats.expiredServicesCount, '${stats.expiredServicesCount} Instance'],
    ];

    final csvContent = csv.encode(rows);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.table_view_rounded, color: AppColors.cyan),
            SizedBox(width: 10),
            Text('Ekspor Laporan (CSV)', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Data ringkasan operasional dan keuangan aktual dari Firebase Firestore siap diekspor:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                height: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvContent,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin Seluruh CSV'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csvContent));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(child: Text('Data rekapitulasi CSV berhasil disalin ke clipboard!')),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(BuildContext context, String label, String value, {bool isBold = false, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelTextColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: labelTextColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: color ?? defaultTextColor,
          ),
        ),
      ],
    );
  }
}
