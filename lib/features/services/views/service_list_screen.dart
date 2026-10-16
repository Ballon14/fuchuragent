import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/service_model.dart';
import 'service_form_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/app_card.dart';

class ServiceListScreen extends ConsumerStatefulWidget {
  const ServiceListScreen({super.key});

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final svc = await ServiceFormDialog.show(context);
    if (svc != null) {
      await ref.read(serviceRepositoryProvider).addService(svc);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan VPS berhasil ditambahkan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceRepo = ref.watch(serviceRepositoryProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Layanan VPS'),
        actions: [
          if (isDesktop)
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah VPS'),
              onPressed: _openCreateDialog,
            )
          else
            IconButton(
              icon: const Icon(Icons.add_task_rounded),
              tooltip: 'Tambah VPS',
              onPressed: _openCreateDialog,
            ),
          const SizedBox(width: 14),
        ],
      ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateDialog,
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Tambah VPS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: StreamBuilder<List<VpsServiceModel>>(
        stream: serviceRepo.watchServices(statusFilter: _statusFilter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          var services = snapshot.data ?? [];
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            services = services.where((s) {
              return s.domain.toLowerCase().contains(q) ||
                  s.packageName.toLowerCase().contains(q) ||
                  (s.worker?.toLowerCase().contains(q) ?? false);
            }).toList();
          }

          return Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter and Search Toolbar (Mobile First)
                if (isDesktop) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 320,
                        child: _buildSearchField(),
                      ),
                      DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.surfaceDark,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                          DropdownMenuItem(value: 'active', child: Text('Hanya Aktif')),
                          DropdownMenuItem(value: 'deactive', child: Text('Hanya Nonaktif')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'suspended', child: Text('Ditangguhkan')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _statusFilter = val);
                        },
                      ),
                      Text(
                        'Menampilkan ${services.length} Layanan VPS',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildSearchField(),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'Semua (${services.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('active', 'Aktif'),
                        const SizedBox(width: 8),
                        _buildFilterChip('pending', 'Pending'),
                        const SizedBox(width: 8),
                        _buildFilterChip('deactive', 'Nonaktif'),
                        const SizedBox(width: 8),
                        _buildFilterChip('suspended', 'Ditangguhkan'),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: isDesktop ? 20 : 14),

                // Content
                Expanded(
                  child: services.isEmpty
                      ? _buildEmptyState()
                      : (isDesktop ? _buildDesktopTable(services) : _buildMobileList(services)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Cari domain, paket, worker...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim()),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _statusFilter = value);
      },
      selectedColor: AppColors.cyan.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.cyan : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.dns_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('Belum ada layanan VPS yang ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Daftarkan VPS baru untuk pelanggan FuchurHost Solutions.', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Layanan VPS'),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<VpsServiceModel> list) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Domain / Host')),
              DataColumn(label: Text('Paket')),
              DataColumn(label: Text('Spesifikasi')),
              DataColumn(label: Text('Harga / Bulan')),
              DataColumn(label: Text('Masa Aktif')),
              DataColumn(label: Text('Worker')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: list.map((s) {
              return DataRow(
                cells: [
                  DataCell(Text(s.domain, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(s.packageName)),
                  DataCell(Text('${s.vcpu} vCPU / ${s.ramGb}GB RAM / ${s.storageGb}GB')),
                  DataCell(Text(AppConstants.formatRupiah(s.price), style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('s.d ${AppConstants.formatShortDate(s.endDate)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (s.isExpired)
                          const Text('Kedaluwarsa', style: TextStyle(fontSize: 10, color: AppColors.danger))
                        else
                          Text('${s.daysUntilExpiry} hari tersisa', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ),
                  DataCell(Text(s.worker ?? '-')),
                  DataCell(StatusBadge(status: s.status)),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: AppColors.cyan),
                      onPressed: () => context.go('/services/${s.id}'),
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
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/services/${s.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.dns_rounded, color: AppColors.cyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.domain,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.packageName} • ${AppConstants.formatRupiah(s.price)}/bln',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: s.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            s.isExpired ? Icons.warning_amber_rounded : Icons.timer_outlined,
                            size: 14,
                            color: s.isExpired ? AppColors.danger : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Exp: ${AppConstants.formatShortDate(s.endDate)} (${s.daysUntilExpiry} hari)',
                            style: TextStyle(
                              fontSize: 11,
                              color: s.isExpired ? AppColors.danger : Colors.white60,
                              fontWeight: s.isExpired ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLightDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${s.vcpu}vCPU / ${s.ramGb}GB RAM',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
