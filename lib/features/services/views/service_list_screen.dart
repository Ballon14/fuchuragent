import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/service_model.dart';
import 'service_form_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_pagination_bar.dart';

class ServiceListScreen extends ConsumerStatefulWidget {
  const ServiceListScreen({super.key});

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

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
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Tambah VPS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: StreamBuilder<List<VpsServiceModel>>(
        stream: serviceRepo.watchServices(statusFilter: _statusFilter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
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

          final totalItems = services.length;
          final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
          final safeCurrentPage = _currentPage.clamp(1, totalPages);
          final startIndex = (safeCurrentPage - 1) * _itemsPerPage;
          final pageServices = services.skip(startIndex).take(_itemsPerPage).toList();

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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceLightDark : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                              DropdownMenuItem(value: 'active', child: Text('Hanya Aktif')),
                              DropdownMenuItem(value: 'deactive', child: Text('Hanya Nonaktif')),
                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'suspended', child: Text('Ditangguhkan')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _statusFilter = val;
                                  _currentPage = 1;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      Text(
                        totalItems > _itemsPerPage
                            ? 'Total $totalItems Layanan VPS (Hal. $safeCurrentPage/$totalPages)'
                            : 'Menampilkan $totalItems Layanan VPS',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          fontSize: 13,
                        ),
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
                      : (isDesktop ? _buildDesktopTable(pageServices) : _buildMobileList(pageServices)),
                ),

                // Pagination Bar (Only when data exceeds itemsPerPage)
                if (totalItems > _itemsPerPage) ...[
                  const SizedBox(height: 14),
                  AppPaginationBar(
                    currentPage: safeCurrentPage,
                    totalItems: totalItems,
                    itemsPerPage: _itemsPerPage,
                    onPageChanged: (newPage) {
                      setState(() => _currentPage = newPage);
                    },
                  ),
                ],
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
                  setState(() {
                    _searchQuery = '';
                    _currentPage = 1;
                  });
                },
              )
            : null,
      ),
      onChanged: (val) => setState(() {
        _searchQuery = val.trim();
        _currentPage = 1;
      }),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final isSelected = _statusFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusFilter = value;
            _currentPage = 1;
          });
        }
      },
      backgroundColor: isDark ? AppColors.surfaceLightDark : Colors.white,
      selectedColor: primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
      side: BorderSide(
        color: isSelected ? primaryColor : (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_rounded, size: 64, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('Belum ada layanan VPS yang ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Daftarkan VPS baru untuk pelanggan FuchurHost Solutions.',
            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

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
                          Text(
                            '${s.daysUntilExpiry} hari tersisa',
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  DataCell(Text(s.worker ?? '-')),
                  DataCell(StatusBadge(status: s.status)),
                  DataCell(
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: primaryColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

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
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.dns_rounded, color: primaryColor, size: 20),
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
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
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
                              color: s.isExpired ? AppColors.danger : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                              fontWeight: s.isExpired ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Text(
                          '${s.vcpu}vCPU / ${s.ramGb}GB RAM',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
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
