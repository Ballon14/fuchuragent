import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../services/services/whatsapp_reminder_service.dart';
import '../../customers/models/customer_model.dart';
import '../../settings/views/google_sheets_backup_dialog.dart';
import '../../settings/services/google_sheets_backup_service.dart';
import '../models/financial_summary_model.dart';

class FinanceMonitoringScreen extends ConsumerStatefulWidget {
  const FinanceMonitoringScreen({super.key});

  @override
  ConsumerState<FinanceMonitoringScreen> createState() => _FinanceMonitoringScreenState();
}

class _FinanceMonitoringScreenState extends ConsumerState<FinanceMonitoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ledgerSearchController = TextEditingController();
  CashflowType? _ledgerTypeFilter; // null = all, inflow, outflow
  String _ledgerSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ledgerSearchController.addListener(() {
      setState(() {
        _ledgerSearchQuery = _ledgerSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ledgerSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentHorizon = ref.watch(selectedHorizonProvider);
    final financeAsync = ref.watch(financialDataStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 960;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring & Analisis Keuangan'),
        actions: [
          financeAsync.when(
            data: (bundle) => TextButton.icon(
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: Text(isDesktop ? 'Ekspor CSV' : 'Ekspor'),
              style: TextButton.styleFrom(
                foregroundColor: primaryAccent,
              ),
              onPressed: () => _showExportCsvDialog(context, bundle),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: Color(0xFF0F9D58)),
            tooltip: 'Cadangkan ke Google Spreadsheet',
            onPressed: () => _openSpreadsheetBackupDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () => ref.invalidate(financialDataStreamProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: financeAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryAccent),
              const SizedBox(height: 16),
              Text(
                'Menganalisis arus kas & mutasi keuangan...',
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
                Text('Gagal memuat analitik keuangan: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  onPressed: () => ref.invalidate(financialDataStreamProvider),
                ),
              ],
            ),
          ),
        ),
        data: (bundle) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(financialDataStreamProvider),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Horizon Filter Bar & Quick Stats
                  _buildHorizonSelector(context, currentHorizon),
                  const SizedBox(height: 16),

                  // Executive Financial KPI Cards
                  _buildExecutiveKpiGrid(context, bundle.metrics, isDesktop),
                  const SizedBox(height: 24),

                  // Tabs Header
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                      unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.bar_chart_rounded, size: 18),
                          text: 'Grafik & Analisis',
                        ),
                        Tab(
                          icon: Icon(Icons.receipt_long_rounded, size: 18),
                          text: 'Buku Kas & Mutasi',
                        ),
                        Tab(
                          icon: Icon(Icons.hourglass_top_rounded, size: 18),
                          text: 'Monitoring Piutang',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab Views Content
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      switch (_tabController.index) {
                        case 0:
                          return _buildChartsTab(context, bundle, isDesktop);
                        case 1:
                          return _buildLedgerTab(context, bundle, isDesktop);
                        case 2:
                          return _buildReceivablesTab(context, bundle, isDesktop);
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // SECTION: HORIZON SELECTOR
  // ==========================================
  Widget _buildHorizonSelector(BuildContext context, TimeFilterHorizon current) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, size: 16, color: primaryAccent),
                const SizedBox(width: 6),
                Text(
                  'Rentang Waktu:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ...TimeFilterHorizon.values.map((horizon) {
            final isSelected = horizon == current;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(horizon.label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(selectedHorizonProvider.notifier).setHorizon(horizon);
                  }
                },
                selectedColor: primaryAccent.withValues(alpha: 0.18),
                backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? primaryAccent
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                side: BorderSide(
                  color: isSelected
                      ? primaryAccent
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION: EXECUTIVE KPI STATS GRID
  // ==========================================
  Widget _buildExecutiveKpiGrid(BuildContext context, FinancialMetrics metrics, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isProfit = metrics.netProfit >= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1100 ? 4 : (width > 600 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: width > 600 ? 16 : 10,
          mainAxisSpacing: width > 600 ? 16 : 10,
          childAspectRatio: width > 1100 ? 2.1 : (width > 600 ? 2.3 : 2.5),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Arus Kas Masuk (Inflow)',
              value: AppConstants.formatRupiah(metrics.totalInflow),
              subtitle: 'Pembayaran Tagihan Terverifikasi',
              icon: Icons.south_west_rounded,
              accentColor: isDark ? AppColors.success : const Color(0xFF059669),
            ),
            StatCard(
              title: 'Arus Kas Keluar (Outflow)',
              value: AppConstants.formatRupiah(metrics.totalOutflow),
              subtitle: 'Beban Operasional & Server',
              icon: Icons.north_east_rounded,
              accentColor: isDark ? AppColors.danger : const Color(0xFFDC2626),
            ),
            StatCard(
              title: 'Laba Bersih Operasional',
              value: AppConstants.formatRupiah(metrics.netProfit),
              subtitle: 'Margin: ${metrics.profitMargin.toStringAsFixed(1)}% • ${isProfit ? "Surplus Kas" : "Defisit Kas"}',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: isProfit
                  ? (isDark ? AppColors.cyan : const Color(0xFF0284C7))
                  : (isDark ? AppColors.danger : const Color(0xFFDC2626)),
            ),
            StatCard(
              title: 'Total Piutang Berjalan',
              value: AppConstants.formatRupiah(metrics.outstandingReceivables),
              subtitle: '${metrics.unpaidInvoicesCount} Tagihan Belum Lunas (${metrics.collectionRate.toStringAsFixed(0)}% Terbayar)',
              icon: Icons.pending_actions_rounded,
              accentColor: isDark ? AppColors.warning : const Color(0xFFD97706),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // SECTION: TAB 1 - CHARTS & VISUAL ANALYTICS
  // ==========================================
  Widget _buildChartsTab(BuildContext context, FinancialDataBundle bundle, bool isDesktop) {
    return Column(
      children: [
        // Monthly Cash Flow Bar Chart
        _buildCashflowBarChartCard(context, bundle.monthlyTrends),
        const SizedBox(height: 20),

        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildExpenseDonutChartCard(context, bundle.expenseCategories, bundle.metrics.totalOutflow)),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: _buildPaymentMethodsCard(context, bundle.paymentMethods, bundle.metrics.totalInflow)),
            ],
          )
        else ...[
          _buildExpenseDonutChartCard(context, bundle.expenseCategories, bundle.metrics.totalOutflow),
          const SizedBox(height: 20),
          _buildPaymentMethodsCard(context, bundle.paymentMethods, bundle.metrics.totalInflow),
        ],
      ],
    );
  }

  Widget _buildCashflowBarChartCard(BuildContext context, List<MonthlyCashflowData> monthlyTrends) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate maximum Y value for nice scaling
    int maxAmount = 0;
    for (final m in monthlyTrends) {
      if (m.inflow > maxAmount) maxAmount = m.inflow;
      if (m.outflow > maxAmount) maxAmount = m.outflow;
    }
    final double maxY = maxAmount > 0 ? (maxAmount * 1.25).toDouble() : 1000000.0;

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < monthlyTrends.length; i++) {
      final data = monthlyTrends[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data.inflow.toDouble(),
              color: isDark ? AppColors.success : const Color(0xFF10B981),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: data.outflow.toDouble(),
              color: isDark ? AppColors.danger : const Color(0xFFEF4444),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return AppCard(
      title: 'Tren Arus Kas Bulanan (6 Bulan Terakhir)',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChartLegend(
            label: 'Kas Masuk',
            color: isDark ? AppColors.success : const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _buildChartLegend(
            label: 'Kas Keluar',
            color: isDark ? AppColors.danger : const Color(0xFFEF4444),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Komparasi Penerimaan Kas Masuk vs Beban Kas Keluar',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.white,
                    tooltipBorder: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final isIncome = rodIndex == 0;
                      final amount = rod.toY.toInt();
                      return BarTooltipItem(
                        '${isIncome ? "Masuk: " : "Keluar: "}${AppConstants.formatRupiah(amount)}',
                        TextStyle(
                          color: isIncome
                              ? (isDark ? AppColors.success : const Color(0xFF059669))
                              : (isDark ? AppColors.danger : const Color(0xFFDC2626)),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < monthlyTrends.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              monthlyTrends[idx].monthLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 58,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          _formatShortAmount(value.toInt()),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildExpenseDonutChartCard(
    BuildContext context,
    List<ExpenseCategoryData> categories,
    int totalOutflow,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (categories.isEmpty || totalOutflow == 0) {
      return AppCard(
        title: 'Alokasi Beban Pengeluaran',
        child: SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 44,
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Belum ada data pengeluaran pada rentang waktu ini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sections = categories.map((cat) {
      return PieChartSectionData(
        color: cat.color,
        value: cat.amount.toDouble(),
        title: cat.percentage >= 8 ? '${cat.percentage.toStringAsFixed(0)}%' : '',
        radius: 36,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return AppCard(
      title: 'Alokasi Beban Pengeluaran',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribusi Beban Menurut Kategori Biaya',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: sections,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Beban Periode:',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppConstants.formatRupiah(totalOutflow),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${categories.length} Kategori Pengeluaran Aktif',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Category Items List
          ...categories.map((cat) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat.categoryLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${cat.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppConstants.formatRupiah(cat.amount),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard(
    BuildContext context,
    List<PaymentMethodDistribution> methods,
    int totalInflow,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (methods.isEmpty || totalInflow == 0) {
      return AppCard(
        title: 'Penerimaan per Kanal Pembayaran',
        child: SizedBox(
          height: 220,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 44,
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Belum ada transaksi pembayaran diterima pada periode ini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppCard(
      title: 'Penerimaan per Kanal Pembayaran',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribusi Pembayaran Masuk Berdasarkan Metode',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          ...methods.map((m) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            m.methodName.toLowerCase().contains('qris')
                                ? Icons.qr_code_scanner_rounded
                                : Icons.account_balance_rounded,
                            size: 16,
                            color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m.methodName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${m.transactionCount} trx)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        AppConstants.formatRupiah(m.totalAmount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: m.percentage / 100,
                      minHeight: 6,
                      backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.cyan : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${m.percentage.toStringAsFixed(1)}% dari total kas masuk',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION: TAB 2 - BUKU KAS & MUTASI TERPADU
  // ==========================================
  Widget _buildLedgerTab(BuildContext context, FinancialDataBundle bundle, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter by type & search query
    final filteredLedger = bundle.ledger.where((item) {
      if (_ledgerTypeFilter != null && item.type != _ledgerTypeFilter) {
        return false;
      }
      if (_ledgerSearchQuery.isNotEmpty) {
        final match = item.title.toLowerCase().contains(_ledgerSearchQuery) ||
            item.partyName.toLowerCase().contains(_ledgerSearchQuery) ||
            item.referenceNumber.toLowerCase().contains(_ledgerSearchQuery) ||
            item.paymentMethod.toLowerCase().contains(_ledgerSearchQuery) ||
            item.categoryLabel.toLowerCase().contains(_ledgerSearchQuery);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Controls Bar
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ledgerSearchController,
                      decoration: InputDecoration(
                        hintText: 'Cari catatan mutasi, pelanggan, nomor referensi...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _ledgerSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => _ledgerSearchController.clear(),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Filter Mutasi:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildLedgerFilterChip('Semua (${bundle.ledger.length})', null),
                      _buildLedgerFilterChip(
                        'Kas Masuk',
                        CashflowType.inflow,
                        color: isDark ? AppColors.success : const Color(0xFF10B981),
                      ),
                      _buildLedgerFilterChip(
                        'Kas Keluar',
                        CashflowType.outflow,
                        color: isDark ? AppColors.danger : const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ledger Transactions List
        if (filteredLedger.isEmpty)
          AppCard(
            child: SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 44,
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada mutasi yang cocok dengan kriteria filter.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredLedger.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = filteredLedger[index];
              return _buildLedgerItemTile(context, item);
            },
          ),
      ],
    );
  }

  Widget _buildLedgerFilterChip(String label, CashflowType? type, {Color? color}) {
    final isSelected = _ledgerTypeFilter == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = color ?? (isDark ? AppColors.cyan : const Color(0xFF0284C7));

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _ledgerTypeFilter = type;
        });
      },
      selectedColor: activeColor.withValues(alpha: 0.18),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? activeColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
      ),
      side: BorderSide(
        color: isSelected ? activeColor : (isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLedgerItemTile(BuildContext context, CashflowLedgerItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInflow = item.isInflow;
    final amountColor = isInflow
        ? (isDark ? AppColors.success : const Color(0xFF059669))
        : (isDark ? AppColors.danger : const Color(0xFFDC2626));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isInflow ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: amountColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.categoryLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: item.categoryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      AppConstants.formatDate(item.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${item.partyName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${item.paymentMethod}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (item.referenceNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Ref: ${item.referenceNumber}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Amount
          Text(
            '${isInflow ? "+" : "-"} ${AppConstants.formatRupiah(item.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION: TAB 3 - MONITORING PIUTANG KRITIS
  // ==========================================
  Widget _buildReceivablesTab(BuildContext context, FinancialDataBundle bundle, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = bundle.agingReceivables;

    if (items.isEmpty) {
      return AppCard(
        child: SizedBox(
          height: 240,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 52,
                  color: AppColors.success,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Semua Tagihan Lunas!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tidak ada piutang tertunda atau tagihan jatuh tempo saat ini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary alert
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.warning : const Color(0xFFFEF3C7)).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.warning.withValues(alpha: 0.4) : const Color(0xFFFCD34D),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ditemukan ${items.length} tagihan belum lunas dengan total piutang ${AppConstants.formatRupiah(bundle.metrics.outstandingReceivables)}. Anda dapat mengirim pengingat WhatsApp dengan 1 sentuhan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // List of aging invoices
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildReceivableCard(context, item);
          },
        ),
      ],
    );
  }

  Widget _buildReceivableCard(BuildContext context, ReceivableAgingItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = item.isOverdue;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? (isDark ? AppColors.danger.withValues(alpha: 0.4) : const Color(0xFFFECACA))
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.invoice.invoiceNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: item.invoice.status),
                ],
              ),
              Text(
                AppConstants.formatRupiah(item.remainingAmount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isOverdue ? AppColors.danger : (isDark ? AppColors.warning : const Color(0xFFD97706)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Customer and due date
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: primaryAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isOverdue ? Icons.error_outline_rounded : Icons.schedule_rounded,
                size: 16,
                color: isOverdue ? AppColors.danger : (isDark ? Colors.white54 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.dueLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                    color: isOverdue
                        ? AppColors.danger
                        : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Detail Tagihan', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => context.push('/invoices/${item.invoice.id}'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                label: const Text('Kirim Pengingat WA', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openWhatsAppReminderDialog(context, item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION: DIALOGS & EXPORT
  // ==========================================
  void _openWhatsAppReminderDialog(BuildContext context, ReceivableAgingItem item) {
    final settings = ref.read(systemSettingsProvider).value;
    final customer = CustomerModel(
      id: item.invoice.customerId,
      name: item.customerName,
      phone: item.customerPhone,
      email: '',
    );

    final templateMessage = WhatsAppReminderService.generateInvoiceReminderTemplate(
      customer: customer,
      invoice: item.invoice,
      settings: settings,
    );

    final msgController = TextEditingController(text: templateMessage);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Template Pengingat Tagihan', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Penerima: ${item.customerName} (${item.customerPhone.isNotEmpty ? item.customerPhone : "Nomor HP belum diisi"})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: msgController,
                    maxLines: 10,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Pesan'),
              onPressed: () {
                WhatsAppReminderService.copyToClipboard(context, msgController.text);
                Navigator.pop(ctx);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Buka WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                WhatsAppReminderService.launchWhatsApp(
                  context: context,
                  phone: item.customerPhone,
                  message: msgController.text,
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showExportCsvDialog(BuildContext context, FinancialDataBundle bundle) {
    final repo = ref.read(financeRepositoryProvider);
    final csvContent = repo.generateFinancialCsv(bundle);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_download_rounded, color: AppColors.cyan),
              SizedBox(width: 10),
              Text('Ekspor Laporan Keuangan (CSV)', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan Arus Kas Periode: ${bundle.horizon.label}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  'Memuat ${bundle.ledger.length} baris mutasi kas terpadu dan ringkasan eksekutif keuangan siap diimpor ke Excel / Google Sheets.',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 120,
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
                      csvContent.split('\n').take(8).join('\n'),
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
                          Expanded(
                            child: Text(
                              'Data Laporan Keuangan CSV berhasil disalin ke clipboard! Siap dipaste ke Excel.',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Color(0xFF10B981),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _formatShortAmount(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)} M';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)} rb';
    }
    return amount.toString();
  }

  void _openSpreadsheetBackupDialog(BuildContext context) async {
    String spreadsheetUrl = GoogleSheetsBackupService.defaultSpreadsheetUrl;
    String webhookUrl = '';
    try {
      final settings = await ref.read(settingsRepositoryProvider).getSettings();
      spreadsheetUrl = settings.spreadsheetBackupUrl;
      webhookUrl = settings.spreadsheetWebhookUrl;
    } catch (_) {}

    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) => GoogleSheetsBackupDialog(
          initialSpreadsheetUrl: spreadsheetUrl,
          initialWebhookUrl: webhookUrl,
        ),
      );
    }
  }
}
