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
        loading: () {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Memuat data aktual Firestore...',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        },
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
                        Expanded(flex: 5, child: _buildServicesOverviewCard(context, stats)),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: _buildFollowUpCard(context, stats)),
                      ],
                    )
                  else ...[
                    _buildServicesOverviewCard(context, stats),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.surfaceDark,
                  AppColors.cyan.withValues(alpha: 0.1),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF0F9FF), // Sky 50
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.cyan.withValues(alpha: 0.2) : const Color(0xFFBAE6FD),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
                      color: (isDark ? AppColors.cyan : const Color(0xFF0284C7)).withValues(alpha: 0.2),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selamat Datang di Fuchur Agent',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sistem VPS & Billing FuchurHost Solutions',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
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
                icon: const Icon(Icons.add_card_rounded, size: 16),
                label: const Text('Catat Pembayaran'),
                onPressed: () => context.go('/payments'),
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

  Widget _buildServicesOverviewCard(BuildContext context, dynamic stats) {
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
              _buildLegend(context, 'Aktif', AppColors.cyan, '${stats.activeServices}'),
              _buildLegend(context, 'Tempo', AppColors.warning, '${stats.expiringServicesCount}'),
              _buildLegend(context, 'Expired', AppColors.danger, '${stats.expiredServicesCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context, String label, Color color, String count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUpCard(BuildContext context, dynamic stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryLinkColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return AppCard(
      title: 'Layanan Perlu Ditindaklanjuti',
      trailing: TextButton(
        onPressed: () => context.go('/renewals'),
        child: Text('Lihat Semua', style: TextStyle(color: primaryLinkColor, fontSize: 12)),
      ),
      child: stats.followUpServices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Tidak ada layanan yang memerlukan tindak lanjut segera.',
                  style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                ),
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
                  leading: Icon(Icons.dns_rounded, color: primaryLinkColor, size: 20),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryLinkColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return AppCard(
      title: 'Pembayaran Terbaru',
      trailing: TextButton(
        onPressed: () => context.go('/payments'),
        child: Text('Kelola Pembayaran', style: TextStyle(color: primaryLinkColor, fontSize: 12)),
      ),
      child: stats.recentPayments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Belum ada transaksi pembayaran tercatat.',
                  style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryLinkColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return AppCard(
      title: 'Pelanggan Terbaru',
      trailing: TextButton(
        onPressed: () => context.go('/customers'),
        child: Text('Daftar Pelanggan', style: TextStyle(color: primaryLinkColor, fontSize: 12)),
      ),
      child: stats.recentCustomers.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Belum ada data pelanggan.',
                  style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                ),
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
                    backgroundColor: primaryLinkColor.withValues(alpha: 0.15),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                      style: TextStyle(fontSize: 11, color: primaryLinkColor, fontWeight: FontWeight.bold),
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryLinkColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final mutedIconColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final mutedTextColor = isDark ? Colors.white38 : const Color(0xFF64748B);

    return AppCard(
      title: 'Aktivitas Administrator Terakhir',
      trailing: TextButton(
        onPressed: () => context.go('/audit'),
        child: Text('Seluruh Log', style: TextStyle(color: primaryLinkColor, fontSize: 12)),
      ),
      child: stats.recentActivities.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Belum ada log audit aktivitas.',
                  style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                ),
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
                  leading: Icon(Icons.history_rounded, size: 18, color: mutedIconColor),
                  title: Text(log.details, style: const TextStyle(fontSize: 12)),
                  subtitle: Text('${log.actorName} • ${AppConstants.formatDateTime(log.timestamp)}', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                  trailing: Text(log.category, style: TextStyle(fontSize: 10, color: primaryLinkColor, fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }
}
