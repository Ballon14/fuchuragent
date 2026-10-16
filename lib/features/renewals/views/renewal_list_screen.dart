import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../services/models/service_model.dart';
import '../models/renewal_model.dart';
import 'renew_action_dialog.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';

class RenewalListScreen extends ConsumerStatefulWidget {
  const RenewalListScreen({super.key});

  @override
  ConsumerState<RenewalListScreen> createState() => _RenewalListScreenState();
}

class _RenewalListScreenState extends ConsumerState<RenewalListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedFilterDays = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serviceRepo = ref.watch(serviceRepositoryProvider);
    final renewalRepo = ref.watch(renewalRepositoryProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Perpanjangan VPS'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.cyan,
          labelColor: AppColors.cyan,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Layanan Akan / Telah Berakhir', icon: Icon(Icons.timer_outlined, size: 18)),
            Tab(text: 'Riwayat Log Perpanjangan', icon: Icon(Icons.history_rounded, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Expiring & Expired Monitor
          Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter interval chips: 30, 14, 7, 3, 1, expired (Mobile First Scrollable)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...[30, 14, 7, 3, 1].map((days) {
                        final selected = _selectedFilterDays == days;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$days Hari'),
                            selected: selected,
                            selectedColor: AppColors.cyan.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: selected ? AppColors.cyan : Colors.white70,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (s) {
                              if (s) setState(() => _selectedFilterDays = days);
                            },
                          ),
                        );
                      }),
                      ChoiceChip(
                        label: const Text('Kedaluwarsa'),
                        selected: _selectedFilterDays == -1,
                        selectedColor: AppColors.danger.withValues(alpha: 0.3),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: _selectedFilterDays == -1 ? AppColors.danger : Colors.white70,
                          fontWeight: _selectedFilterDays == -1 ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (s) {
                          if (s) setState(() => _selectedFilterDays = -1);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isDesktop ? 20 : 14),

                Expanded(
                  child: FutureBuilder<List<VpsServiceModel>>(
                    future: _selectedFilterDays == -1
                        ? serviceRepo.getExpiredServices()
                        : serviceRepo.getExpiringServices(_selectedFilterDays),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
                      }

                      final services = snapshot.data ?? [];
                      if (services.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 56),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFilterDays == -1
                                    ? 'Tidak ada layanan yang kedaluwarsa.'
                                    : 'Semua layanan aman! Tidak ada yang berakhir dalam $_selectedFilterDays hari.',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }

                      return isDesktop
                          ? _buildDesktopTable(services)
                          : _buildMobileList(services);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Tab 2: Renewals Log History
          StreamBuilder<List<ServiceRenewalModel>>(
            stream: renewalRepo.watchRenewals(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
              }
              final renewals = snapshot.data ?? [];
              if (renewals.isEmpty) {
                return const Center(child: Text('Belum ada riwayat perpanjangan.', style: TextStyle(color: Colors.white38)));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: renewals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final r = renewals[idx];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.autorenew_rounded, color: AppColors.cyan),
                      title: Text('Perpanjangan +${r.durationMonths} Bulan', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Jatuh Tempo Baru: ${AppConstants.formatDate(r.newEndDate)} • Dicatat: ${AppConstants.formatDateTime(r.createdAt)}',
                      ),
                      trailing: Text(r.notes.isNotEmpty ? r.notes : 'Selesai', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<VpsServiceModel> list) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Domain VPS')),
              DataColumn(label: Text('Paket')),
              DataColumn(label: Text('Tanggal Berakhir')),
              DataColumn(label: Text('Sisa Hari')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Tindakan')),
            ],
            rows: list.map((s) {
              return DataRow(
                cells: [
                  DataCell(Text(s.domain, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(s.packageName)),
                  DataCell(Text(AppConstants.formatDate(s.endDate))),
                  DataCell(
                    Text(
                      s.isExpired ? 'Telah Kedaluwarsa' : '${s.daysUntilExpiry} Hari',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: s.isExpired ? AppColors.danger : (s.daysUntilExpiry <= 3 ? AppColors.danger : AppColors.warning),
                      ),
                    ),
                  ),
                  DataCell(StatusBadge(status: s.status)),
                  DataCell(
                    ElevatedButton.icon(
                      icon: const Icon(Icons.autorenew_rounded, size: 14),
                      label: const Text('Perpanjang', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        await RenewActionDialog.show(context, service: s);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<VpsServiceModel> list) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final s = list[idx];
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.timer_rounded,
              color: s.isExpired ? AppColors.danger : AppColors.warning,
            ),
            title: Text(s.domain, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Tempo: ${AppConstants.formatDate(s.endDate)}'),
                Text(
                  s.isExpired ? 'Kedaluwarsa' : '${s.daysUntilExpiry} hari tersisa',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: s.isExpired ? AppColors.danger : AppColors.warning,
                  ),
                ),
              ],
            ),
            trailing: ElevatedButton(
              child: const Text('Perpanjang', style: TextStyle(fontSize: 11)),
              onPressed: () async {
                await RenewActionDialog.show(context, service: s);
                setState(() {});
              },
            ),
          ),
        );
      },
    );
  }
}
