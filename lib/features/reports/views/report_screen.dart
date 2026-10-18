import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_card.dart';

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
                  'Rekapitulasi Kinerja Bisnis FuchurHost Solutions',
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
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('File rekap CSV disiapkan untuk diunduh.')),
                              );
                            },
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                            label: const Text('Cetak Rekap PDF'),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Fitur cetak PDF siap diintegrasikan.')),
                              );
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
