import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Operasional'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.cyan),
              SizedBox(height: 16),
              Text('Memuat data aktual Firestore...', style: TextStyle(color: Colors.white60)),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                const SizedBox(height: 16),
                Text('Gagal memuat dashboard: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  onPressed: () => ref.invalidate(dashboardStatsProvider),
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardStatsProvider),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Banner / Quick Actions
                  _buildQuickActionBanner(context),
                  SizedBox(height: isDesktop ? 24 : 14),

                  // Top Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width > 1100 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: width > 600 ? 16 : 10,
                        mainAxisSpacing: width > 600 ? 16 : 10,
                        childAspectRatio: width > 1100 ? 1.8 : (width > 600 ? 2.0 : 1.4),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          StatCard(
                            title: 'Total Pelanggan',
                            value: '${stats.totalCustomers}',
                            subtitle: '${stats.activeCustomers} Pelanggan Aktif',
                            icon: Icons.people_alt_rounded,
                            accentColor: AppColors.cyan,
                            onTap: () => context.go('/customers'),
                          ),
                          StatCard(
                            title: 'Layanan VPS',
                            value: '${stats.totalServices}',
                            subtitle: '${stats.activeServices} VPS Aktif Operasional',
                            icon: Icons.dns_rounded,
                            accentColor: AppColors.electricBlue,
                            onTap: () => context.go('/services'),
                          ),
                          StatCard(
                            title: 'Mendekati Jatuh Tempo',
                            value: '${stats.expiringServicesCount}',
                            subtitle: '${stats.expiredServicesCount} Layanan Kedaluwarsa',
                            icon: Icons.timer_outlined,
                            accentColor: AppColors.warning,
                            onTap: () => context.go('/renewals'),
                          ),
                          StatCard(
                            title: 'Pendapatan Diterima',
                            value: AppConstants.formatRupiah(stats.totalRevenue),
                            subtitle: 'Tagihan Tertunggak: ${AppConstants.formatRupiah(stats.unpaidAmount)}',
                            icon: Icons.account_balance_wallet_rounded,
                            accentColor: AppColors.success,
                            onTap: () => context.go('/payments'),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Middle Section: Chart & Follow-up services
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildServicesOverviewCard(stats)),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: _buildFollowUpCard(context, stats)),
                      ],
                    )
                  else ...[
                    _buildServicesOverviewCard(stats),
                    const SizedBox(height: 24),
                    _buildFollowUpCard(context, stats),
                  ],

                  const SizedBox(height: 24),

                  // Bottom Section: Recent Payments & Recent Customers
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildRecentPaymentsCard(context, stats)),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: _buildRecentCustomersCard(context, stats)),
                      ],
                    )
                  else ...[
                    _buildRecentPaymentsCard(context, stats),
                    const SizedBox(height: 24),
                    _buildRecentCustomersCard(context, stats),
                  ],

                  const SizedBox(height: 24),

                  // Admin Activity Log Card
                  _buildRecentActivitiesCard(context, stats),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceDark,
            AppColors.cyan.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(AppConstants.logoAsset, width: 44, height: 44, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang di Fuchur Agent',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Sistem VPS & Billing FuchurHost Solutions',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.cloud_download_rounded, size: 16),
                label: const Text('Impor Spreadsheet'),
                onPressed: () => context.go('/imports'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Pelanggan Baru'),
                onPressed: () => context.go('/customers'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: const Text('Tambah VPS'),
                onPressed: () => context.go('/services'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesOverviewCard(dynamic stats) {
    return AppCard(
      title: 'Status Layanan VPS',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: stats.activeServices.toDouble() > 0 ? stats.activeServices.toDouble() : 1,
                    color: AppColors.cyan,
                    title: '${stats.activeServices}',
                    radius: 40,
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13),
                  ),
                  PieChartSectionData(
                    value: stats.expiringServicesCount.toDouble(),
                    color: AppColors.warning,
                    title: '${stats.expiringServicesCount}',
                    radius: 40,
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13),
                  ),
                  PieChartSectionData(
                    value: stats.expiredServicesCount.toDouble(),
                    color: AppColors.danger,
                    title: '${stats.expiredServicesCount}',
                    radius: 40,
                    titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegend('Aktif', AppColors.cyan, '${stats.activeServices}'),
              _buildLegend('Tempo', AppColors.warning, '${stats.expiringServicesCount}'),
              _buildLegend('Expired', AppColors.danger, '${stats.expiredServicesCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color, String count) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ($count)', style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildFollowUpCard(BuildContext context, dynamic stats) {
    return AppCard(
      title: 'Layanan Perlu Ditindaklanjuti',
      trailing: TextButton(
        onPressed: () => context.go('/renewals'),
        child: const Text('Lihat Semua', style: TextStyle(color: AppColors.cyan, fontSize: 12)),
      ),
      child: stats.followUpServices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Tidak ada layanan yang memerlukan tindak lanjut segera.', style: TextStyle(color: Colors.white38)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.followUpServices.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final svc = stats.followUpServices[idx];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.dns_rounded, color: AppColors.cyan, size: 20),
                  title: Text(svc.domain, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Jatuh Tempo: ${AppConstants.formatShortDate(svc.endDate)}', style: const TextStyle(fontSize: 11)),
                  trailing: StatusBadge(status: svc.status),
                  onTap: () => context.go('/services/${svc.id}'),
                );
              },
            ),
    );
  }

  Widget _buildRecentPaymentsCard(BuildContext context, dynamic stats) {
    return AppCard(
      title: 'Pembayaran Terbaru',
      trailing: TextButton(
        onPressed: () => context.go('/payments'),
        child: const Text('Kelola Pembayaran', style: TextStyle(color: AppColors.cyan, fontSize: 12)),
      ),
      child: stats.recentPayments.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada transaksi pembayaran tercatat.', style: TextStyle(color: Colors.white38)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.recentPayments.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = stats.recentPayments[idx];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payment_rounded, color: AppColors.success, size: 20),
                  title: Text(AppConstants.formatRupiah(p.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('${p.paymentMethod} • ${AppConstants.formatShortDate(p.paymentDate)}', style: const TextStyle(fontSize: 11)),
                  trailing: StatusBadge(status: p.isReversed ? 'dibatalkan' : 'lunas'),
                );
              },
            ),
    );
  }

  Widget _buildRecentCustomersCard(BuildContext context, dynamic stats) {
    return AppCard(
      title: 'Pelanggan Terbaru',
      trailing: TextButton(
        onPressed: () => context.go('/customers'),
        child: const Text('Daftar Pelanggan', style: TextStyle(color: AppColors.cyan, fontSize: 12)),
      ),
      child: stats.recentCustomers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada data pelanggan.', style: TextStyle(color: Colors.white38)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.recentCustomers.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final c = stats.recentCustomers[idx];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.cyan.withValues(alpha: 0.2),
                    child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C', style: const TextStyle(fontSize: 11, color: AppColors.cyan)),
                  ),
                  title: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(c.phone, style: const TextStyle(fontSize: 11)),
                  trailing: StatusBadge(status: c.status),
                  onTap: () => context.go('/customers/${c.id}'),
                );
              },
            ),
    );
  }

  Widget _buildRecentActivitiesCard(BuildContext context, dynamic stats) {
    return AppCard(
      title: 'Aktivitas Administrator Terakhir',
      trailing: TextButton(
        onPressed: () => context.go('/audit'),
        child: const Text('Seluruh Log', style: TextStyle(color: AppColors.cyan, fontSize: 12)),
      ),
      child: stats.recentActivities.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada log audit aktivitas.', style: TextStyle(color: Colors.white38)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.recentActivities.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final log = stats.recentActivities[idx];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded, size: 18, color: Colors.white38),
                  title: Text(log.details, style: const TextStyle(fontSize: 12)),
                  subtitle: Text('${log.actorName} • ${AppConstants.formatDateTime(log.timestamp)}', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  trailing: Text(log.category, style: const TextStyle(fontSize: 10, color: AppColors.cyan, fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }
}
