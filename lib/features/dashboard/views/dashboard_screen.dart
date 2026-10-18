import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/dashboard_stats.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../services/views/service_form_dialog.dart';
import '../../services/views/whatsapp_reminder_dialog.dart';
import '../../customers/views/customer_form_dialog.dart';
import '../../payments/views/record_payment_dialog.dart';
import '../../expenses/views/expense_form_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _touchedDonutIndex = -1;
  String _activityFilter = 'ALL'; // 'ALL', 'SERVICE', 'INVOICE', 'EXPENSE', 'CUSTOMER'
  bool _isRefreshing = false;
  DateTime _lastRefreshTime = DateTime.now();

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      ref.invalidate(dashboardStatsProvider);
      await ref.read(dashboardStatsProvider.future);
      if (mounted) {
        setState(() {
          _lastRefreshTime = DateTime.now();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Operasional'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Update: ${DateFormat('HH:mm').format(_lastRefreshTime)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data Sekarang',
            onPressed: _isRefreshing ? null : _refreshData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
              ),
              const SizedBox(height: 16),
              Text(
                'Sinkronisasi data aktual dari Firestore...',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
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
                  onPressed: _refreshData,
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          return RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isDesktop ? 24 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Welcome Banner & Direct Action Modals
                  _buildQuickActionBanner(context, isDark, isDesktop),
                  SizedBox(height: isDesktop ? 20 : 14),

                  // 2. Interactive KPI Stats Grid
                  _buildStatsGrid(context, stats),
                  const SizedBox(height: 24),

                  // 3. Middle Section: Enhanced Interactive Donut Chart & Follow-up services
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildServicesOverviewCard(context, stats, isDark)),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: _buildFollowUpCard(context, stats, isDark, primaryColor)),
                      ],
                    )
                  else ...[
                    _buildServicesOverviewCard(context, stats, isDark),
                    const SizedBox(height: 20),
                    _buildFollowUpCard(context, stats, isDark, primaryColor),
                  ],

                  const SizedBox(height: 24),

                  // 4. Bottom Section: Recent Payments & Recent Customers
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildRecentPaymentsCard(context, stats, isDark, primaryColor)),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: _buildRecentCustomersCard(context, stats, isDark, primaryColor)),
                      ],
                    )
                  else ...[
                    _buildRecentPaymentsCard(context, stats, isDark, primaryColor),
                    const SizedBox(height: 20),
                    _buildRecentCustomersCard(context, stats, isDark, primaryColor),
                  ],

                  const SizedBox(height: 24),

                  // 5. Admin Activity Log Card with category filtering
                  _buildRecentActivitiesCard(context, stats, isDark, primaryColor),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 1. QUICK ACTION BANNER WITH ONE-CLICK MODAL LAUNCHERS
  // ===========================================================================
  Widget _buildQuickActionBanner(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.surfaceDark,
                  AppColors.cyan.withValues(alpha: 0.12),
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
          color: isDark ? AppColors.cyan.withValues(alpha: 0.25) : const Color(0xFFBAE6FD),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF0284C7)).withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppColors.cyan : const Color(0xFF0284C7)).withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(AppConstants.logoAsset, width: 40, height: 40, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pusat Kendali Operasional FuchurAgent',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kelola server, keuangan kas, dan pantau jatuh tempo tagihan pelanggan secara real-time.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Quick Action Modal Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_card_rounded, size: 16),
                label: const Text('+ Catat Kas Masuk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () async {
                  final res = await RecordPaymentDialog.show(context);
                  if (res != null) _refreshData();
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('+ Pelanggan Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () async {
                  final res = await CustomerFormDialog.show(context);
                  if (res != null) {
                    await ref.read(customerRepositoryProvider).addCustomer(res);
                    _refreshData();
                  }
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.dns_rounded, size: 16),
                label: const Text('+ Tambah Layanan VPS', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                onPressed: () async {
                  final res = await ServiceFormDialog.show(context);
                  if (res != null) {
                    await ref.read(serviceRepositoryProvider).addService(res);
                    _refreshData();
                  }
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                label: const Text('+ Catat Biaya/Pengeluaran', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                onPressed: () async {
                  final res = await ExpenseFormDialog.show(context);
                  if (res != null) {
                    await ref.read(expenseRepositoryProvider).addExpense(res);
                    _refreshData();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. STATS KPI GRID
  // ===========================================================================
  Widget _buildStatsGrid(BuildContext context, DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1100 ? 4 : (width > 600 ? 2 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: width > 600 ? 16 : 10,
          mainAxisSpacing: width > 600 ? 16 : 10,
          childAspectRatio: width > 1100 ? 1.85 : (width > 600 ? 2.0 : 1.45),
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
              subtitle: '${stats.activeServices} VPS Aktif Beroperasi',
              icon: Icons.dns_rounded,
              accentColor: AppColors.electricBlue,
              onTap: () => context.go('/services'),
            ),
            StatCard(
              title: 'Jatuh Tempo / Expired',
              value: '${stats.expiringServicesCount}',
              subtitle: '${stats.expiredServicesCount} Layanan Telah Expired',
              icon: Icons.timer_outlined,
              accentColor: AppColors.warning,
              onTap: () => context.go('/renewals'),
            ),
            StatCard(
              title: 'Pendapatan Diterima',
              value: AppConstants.formatRupiah(stats.totalRevenue),
              subtitle: 'Biaya: ${AppConstants.formatRupiah(stats.totalExpenses)} • Laba: ${AppConstants.formatRupiah(stats.netProfit)}',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: AppColors.success,
              onTap: () => context.go('/payments'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 3. PERFECTED INTERACTIVE DONUT CHART
  // ===========================================================================
  Widget _buildServicesOverviewCard(BuildContext context, DashboardStats stats, bool isDark) {
    final activeCount = stats.activeServices;
    final expiringCount = stats.expiringServicesCount;
    final expiredCount = stats.expiredServicesCount;
    final total = activeCount + expiringCount + expiredCount;

    // Define slices
    final items = [
      _DonutCategory(
        index: 0,
        label: 'Aktif',
        count: activeCount,
        color: AppColors.cyan,
        route: '/services',
      ),
      _DonutCategory(
        index: 1,
        label: 'Tempo',
        count: expiringCount,
        color: AppColors.warning,
        route: '/renewals',
      ),
      _DonutCategory(
        index: 2,
        label: 'Expired',
        count: expiredCount,
        color: AppColors.danger,
        route: '/renewals',
      ),
    ];

    final validItems = items.where((it) => it.count > 0).toList();

    return AppCard(
      title: 'Status Layanan VPS (Interaktif)',
      trailing: TextButton.icon(
        icon: const Icon(Icons.open_in_new_rounded, size: 14),
        label: const Text('Kelola Layanan', style: TextStyle(fontSize: 12)),
        onPressed: () => context.go('/services'),
      ),
      child: Column(
        children: [
          // Donut Chart with Dynamic Center Info Stack
          SizedBox(
            height: 220,
            child: total == 0
                ? _buildEmptyDonutChart(isDark)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 52,
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedDonutIndex = -1;
                                  return;
                                }
                                final touchedSectionIdx = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                if (touchedSectionIdx >= 0 && touchedSectionIdx < validItems.length) {
                                  _touchedDonutIndex = validItems[touchedSectionIdx].index;
                                } else {
                                  _touchedDonutIndex = -1;
                                }
                              });
                            },
                          ),
                          sections: validItems.map((item) {
                            final isTouched = _touchedDonutIndex == item.index;
                            final pct = ((item.count / total) * 100).toStringAsFixed(0);

                            return PieChartSectionData(
                              value: item.count.toDouble(),
                              color: item.color,
                              radius: isTouched ? 48.0 : 38.0,
                              title: '$pct%',
                              titleStyle: TextStyle(
                                fontSize: isTouched ? 14 : 11,
                                fontWeight: FontWeight.bold,
                                color: item.color == AppColors.cyan ? Colors.black : Colors.white,
                              ),
                              badgeWidget: isTouched
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: item.color.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${item.count} VPS',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                              badgePositionPercentageOffset: 1.25,
                            );
                          }).toList(),
                        ),
                      ),

                      // Interactive Center Content
                      _buildDonutCenterInfo(stats, total, isDark),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // Interactive Legends with percentages and click-to-highlight/navigate
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: items.map((item) {
              final isHighlighted = _touchedDonutIndex == item.index;
              final pct = total > 0 ? ((item.count / total) * 100).toStringAsFixed(0) : '0';

              return InkWell(
                onTap: () {
                  setState(() {
                    _touchedDonutIndex = _touchedDonutIndex == item.index ? -1 : item.index;
                  });
                },
                onDoubleTap: () => context.go(item.route),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? item.color.withValues(alpha: isDark ? 0.25 : 0.15)
                        : (isDark ? AppColors.surfaceLightDark : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isHighlighted ? item.color : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                      width: isHighlighted ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                          color: isHighlighted
                              ? (isDark ? Colors.white : item.color)
                              : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${item.count} • $pct%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isHighlighted ? item.color : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            'Tip: Ketuk kategori untuk highlight slice, atau double-tap untuk buka daftar.',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDonutChart(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 0,
            centerSpaceRadius: 52,
            sections: [
              PieChartSectionData(
                value: 1,
                color: isDark ? AppColors.surfaceLightDark : const Color(0xFFE2E8F0),
                radius: 36,
                showTitle: false,
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 28, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
            const SizedBox(height: 4),
            Text(
              '0 Layanan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            Text(
              'Belum ada data',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDonutCenterInfo(DashboardStats stats, int total, bool isDark) {
    if (_touchedDonutIndex == 0) {
      final pct = total > 0 ? ((stats.activeServices / total) * 100).toStringAsFixed(1) : '0';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${stats.activeServices}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.cyan),
          ),
          const Text(
            'Aktif',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyan),
          ),
          Text(
            '$pct% dari total',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
          ),
        ],
      );
    } else if (_touchedDonutIndex == 1) {
      final pct = total > 0 ? ((stats.expiringServicesCount / total) * 100).toStringAsFixed(1) : '0';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${stats.expiringServicesCount}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.warning),
          ),
          const Text(
            'Mendekati Tempo',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
          ),
          Text(
            '$pct% dari total',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
          ),
        ],
      );
    } else if (_touchedDonutIndex == 2) {
      final pct = total > 0 ? ((stats.expiredServicesCount / total) * 100).toStringAsFixed(1) : '0';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${stats.expiredServicesCount}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.danger),
          ),
          const Text(
            'Kedaluwarsa',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.danger),
          ),
          Text(
            '$pct% dari total',
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
          ),
        ],
      );
    }

    // Default center info when untouched
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${stats.totalServices}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(
          'Total VPS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, size: 10, color: isDark ? AppColors.cyan : const Color(0xFF0284C7)),
            const SizedBox(width: 2),
            Text(
              'Sentuh slice',
              style: TextStyle(
                fontSize: 9,
                color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. INTERACTIVE FOLLOW-UP SERVICES CARD (WITH WHATSAPP REMINDER BUTTON)
  // ===========================================================================
  Widget _buildFollowUpCard(BuildContext context, DashboardStats stats, bool isDark, Color primaryColor) {
    return AppCard(
      title: 'Layanan Perlu Ditindaklanjuti',
      trailing: TextButton.icon(
        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
        label: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
        onPressed: () => context.go('/renewals'),
      ),
      child: stats.followUpServices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.success, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'Semua server aman!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tidak ada layanan yang memerlukan tindak lanjut segera.',
                      style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
                final now = DateTime.now();
                final endDate = svc.endDate ?? now;
                final isExpired = svc.endDate != null && svc.endDate!.isBefore(now);
                final diffDays = isExpired ? now.difference(endDate).inDays : endDate.difference(now).inDays + 1;

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isExpired ? AppColors.danger : AppColors.warning).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.dns_rounded,
                      color: isExpired ? AppColors.danger : AppColors.warning,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    svc.domain,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        'Exp: ${AppConstants.formatShortDate(svc.endDate)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: (isExpired ? AppColors.danger : AppColors.warning).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isExpired ? 'Lewat $diffDays hari' : '$diffDays hari lagi',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isExpired ? AppColors.danger : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                        tooltip: 'Kirim Pengingat WhatsApp',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          WhatsAppReminderDialog.show(context, service: svc);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        tooltip: 'Lihat Detail',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context.go('/services/${svc.id}'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // 5. INTERACTIVE RECENT PAYMENTS CARD
  // ===========================================================================
  Widget _buildRecentPaymentsCard(BuildContext context, DashboardStats stats, bool isDark, Color primaryColor) {
    return AppCard(
      title: 'Pembayaran Terbaru',
      trailing: TextButton.icon(
        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
        label: const Text('Kelola Kas', style: TextStyle(fontSize: 12)),
        onPressed: () => context.go('/payments'),
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
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payment_rounded, color: AppColors.success, size: 18),
                  ),
                  title: Text(
                    AppConstants.formatRupiah(p.amount),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${p.paymentMethod} • ${AppConstants.formatShortDate(p.paymentDate)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(status: p.isReversed ? 'dibatalkan' : 'lunas'),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        tooltip: 'Salin ID Pembayaran',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: p.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ID Pembayaran ${p.id} disalin ke clipboard.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // 6. INTERACTIVE RECENT CUSTOMERS CARD
  // ===========================================================================
  Widget _buildRecentCustomersCard(BuildContext context, DashboardStats stats, bool isDark, Color primaryColor) {
    return AppCard(
      title: 'Pelanggan Terbaru',
      trailing: TextButton.icon(
        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
        label: const Text('Daftar Pelanggan', style: TextStyle(fontSize: 12)),
        onPressed: () => context.go('/customers'),
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
                    radius: 16,
                    backgroundColor: primaryColor.withValues(alpha: 0.15),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                      style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(c.phone, style: const TextStyle(fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(status: c.status),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        tooltip: 'Detail Pelanggan',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context.go('/customers/${c.id}'),
                      ),
                    ],
                  ),
                  onTap: () => context.go('/customers/${c.id}'),
                );
              },
            ),
    );
  }

  // ===========================================================================
  // 7. ADMIN ACTIVITY LOG CARD WITH CATEGORY FILTERING
  // ===========================================================================
  Widget _buildRecentActivitiesCard(BuildContext context, DashboardStats stats, bool isDark, Color primaryColor) {
    var activities = stats.recentActivities;
    if (_activityFilter != 'ALL') {
      activities = activities.where((act) => act.category.toUpperCase().contains(_activityFilter)).toList();
    }

    final mutedIconColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final mutedTextColor = isDark ? Colors.white38 : const Color(0xFF64748B);

    return AppCard(
      title: 'Aktivitas Administrator Terakhir',
      trailing: TextButton.icon(
        icon: const Icon(Icons.history_edu_rounded, size: 14),
        label: const Text('Seluruh Log', style: TextStyle(fontSize: 12)),
        onPressed: () => context.go('/audit'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActivityFilterChip('Semua', 'ALL', isDark, primaryColor),
                const SizedBox(width: 6),
                _buildActivityFilterChip('Layanan', 'SERVICE', isDark, primaryColor),
                const SizedBox(width: 6),
                _buildActivityFilterChip('Tagihan', 'INVOICE', isDark, primaryColor),
                const SizedBox(width: 6),
                _buildActivityFilterChip('Kas', 'PAYMENT', isDark, primaryColor),
                const SizedBox(width: 6),
                _buildActivityFilterChip('Biaya', 'EXPENSE', isDark, primaryColor),
                const SizedBox(width: 6),
                _buildActivityFilterChip('Pelanggan', 'CUSTOMER', isDark, primaryColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          activities.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Belum ada log aktivitas untuk kategori ini.',
                      style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final log = activities[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.history_rounded, size: 18, color: mutedIconColor),
                      title: Text(log.details, style: const TextStyle(fontSize: 12)),
                      subtitle: Text(
                        '${log.actorName} • ${AppConstants.formatDateTime(log.timestamp)}',
                        style: TextStyle(fontSize: 11, color: mutedTextColor),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.category,
                          style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildActivityFilterChip(String label, String code, bool isDark, Color primaryColor) {
    final isSelected = _activityFilter == code;
    return InkWell(
      onTap: () => setState(() => _activityFilter = code),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? primaryColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

class _DonutCategory {
  final int index;
  final String label;
  final int count;
  final Color color;
  final String route;

  const _DonutCategory({
    required this.index,
    required this.label,
    required this.count,
    required this.color,
    required this.route,
  });
}
