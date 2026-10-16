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
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.cyan)),
        error: (err, _) => Center(child: Text('Gagal memuat laporan: $err')),
        data: (stats) {
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
                const Text(
                  'Zona Waktu: Asia/Jakarta • Mata Uang: IDR (Rupiah)',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 20),

                // Financial Summary Card
                AppCard(
                  title: 'Ringkasan Keuangan & Tagihan',
                  child: Column(
                    children: [
                      _buildReportRow(
                        'Total Pendapatan Diterima (Kas Masuk Aktual)',
                        AppConstants.formatRupiah(stats.totalRevenue),
                        color: AppColors.success,
                        isBold: true,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        'Total Piutang / Tagihan Belum Dibayar',
                        AppConstants.formatRupiah(stats.unpaidAmount),
                        color: AppColors.warning,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        'Jumlah Tagihan Terbuka',
                        '${stats.unpaidInvoicesCount} Tagihan',
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        'Jumlah Tagihan Melewati Jatuh Tempo (Overdue)',
                        '${stats.overdueInvoicesCount} Tagihan',
                        color: stats.overdueInvoicesCount > 0 ? AppColors.danger : Colors.white70,
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
                        'Total Pelanggan Terdaftar',
                        '${stats.totalCustomers} Pelanggan',
                        isBold: true,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        'Pelanggan Aktif',
                        '${stats.activeCustomers} Pelanggan',
                        color: AppColors.cyan,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        'Total Instance Layanan VPS',
                        '${stats.totalServices} Layanan',
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        'Layanan VPS Aktif',
                        '${stats.activeServices} Instance',
                        color: AppColors.cyan,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        'Layanan Mendekati Jatuh Tempo (≤ 7 Hari)',
                        '${stats.expiringServicesCount} Instance',
                        color: AppColors.warning,
                      ),
                      const Divider(height: 16),
                      _buildReportRow(
                        'Layanan Telah Kedaluwarsa',
                        '${stats.expiredServicesCount} Instance',
                        color: AppColors.danger,
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
                      const Text(
                        'Unduh data rekapitulasi untuk keperluan pembukuan atau audit:',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
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

  Widget _buildReportRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: isBold ? 15 : 13, fontWeight: FontWeight.bold, color: color ?? Colors.white)),
      ],
    );
  }
}
