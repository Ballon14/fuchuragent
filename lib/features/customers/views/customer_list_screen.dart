import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/customer_model.dart';
import 'customer_form_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_pagination_bar.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
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
    final customer = await CustomerFormDialog.show(context);
    if (customer != null) {
      await ref.read(customerRepositoryProvider).addCustomer(customer);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pelanggan berhasil ditambahkan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerRepo = ref.watch(customerRepositoryProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pelanggan'),
        actions: [
          if (isDesktop)
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Pelanggan'),
              onPressed: _openCreateDialog,
            )
          else
            IconButton(
              icon: const Icon(Icons.person_add_rounded),
              tooltip: 'Tambah Pelanggan',
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
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Pelanggan Baru', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: StreamBuilder<List<CustomerModel>>(
        stream: customerRepo.watchCustomers(statusFilter: _statusFilter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          var customers = snapshot.data ?? [];
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            customers = customers.where((c) {
              return c.name.toLowerCase().contains(q) ||
                  c.phone.contains(q) ||
                  c.sourceId.toLowerCase().contains(q);
            }).toList();
          }

          final totalItems = customers.length;
          final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
          final safeCurrentPage = _currentPage.clamp(1, totalPages);
          final startIndex = (safeCurrentPage - 1) * _itemsPerPage;
          final pageCustomers = customers.skip(startIndex).take(_itemsPerPage).toList();

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
                              DropdownMenuItem(value: 'inactive', child: Text('Hanya Nonaktif')),
                              DropdownMenuItem(value: 'archived', child: Text('Diarsipkan')),
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
                            ? 'Total $totalItems Pelanggan (Hal. $safeCurrentPage/$totalPages)'
                            : 'Menampilkan $totalItems Pelanggan',
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
                        _buildFilterChip('all', 'Semua (${customers.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('active', 'Aktif'),
                        const SizedBox(width: 8),
                        _buildFilterChip('inactive', 'Nonaktif'),
                        const SizedBox(width: 8),
                        _buildFilterChip('archived', 'Diarsipkan'),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: isDesktop ? 20 : 14),

                // Data List / Table
                Expanded(
                  child: customers.isEmpty
                      ? _buildEmptyState()
                      : (isDesktop ? _buildDesktopTable(pageCustomers) : _buildMobileList(pageCustomers)),
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
        hintText: 'Cari nama, WhatsApp, ID pelanggan...',
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
          Icon(Icons.person_search_rounded, size: 64, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('Tidak ada pelanggan yang ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Tambahkan pelanggan baru untuk mulai mengelola layanan VPS.',
            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Pelanggan'),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<CustomerModel> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
      color: isDark ? Colors.white70 : const Color(0xFF64748B),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header Tabel (Memanfaatkan 100% lebar layar, tanpa scroll horizontal)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceLightDark.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('ID PELANGGAN', style: headerStyle)),
                Expanded(flex: 4, child: Text('NAMA PELANGGAN', style: headerStyle)),
                Expanded(flex: 3, child: Text('NOMOR HP / WA', style: headerStyle)),
                Expanded(flex: 3, child: Text('EMAIL', style: headerStyle)),
                Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
                Expanded(flex: 2, child: Text('TERDAFTAR', style: headerStyle)),
                SizedBox(
                  width: 44,
                  child: Center(child: Text('AKSI', style: headerStyle)),
                ),
              ],
            ),
          ),

          // Daftar Baris Pelanggan (Pas satu layar, interaktif dengan hover)
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.borderLight,
              ),
              itemBuilder: (context, idx) {
                final c = list[idx];
                return InkWell(
                  onTap: () => context.go('/customers/${c.id}'),
                  hoverColor: primaryColor.withValues(alpha: 0.05),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // ID Pelanggan
                        Expanded(
                          flex: 2,
                          child: Text(
                            c.sourceId.isNotEmpty ? c.sourceId : '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),

                        // Nama Pelanggan
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: primaryColor.withValues(alpha: 0.15),
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                  style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Nomor HP / WA
                        Expanded(
                          flex: 3,
                          child: Text(
                            c.phone,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Email
                        Expanded(
                          flex: 3,
                          child: Text(
                            c.email ?? '-',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Status
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(status: c.status),
                          ),
                        ),

                        // Terdaftar
                        Expanded(
                          flex: 2,
                          child: Text(
                            AppConstants.formatShortDate(c.createdAt),
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Aksi
                        SizedBox(
                          width: 44,
                          child: IconButton(
                            icon: Icon(Icons.chevron_right_rounded, color: primaryColor, size: 20),
                            tooltip: 'Detail Pelanggan',
                            onPressed: () => context.go('/customers/${c.id}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<CustomerModel> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final c = list[idx];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/customers/${c.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: primaryColor.withValues(alpha: 0.15),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: c.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_android_rounded, size: 13, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              c.phone,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                            if (c.sourceId.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                  ),
                                ),
                                child: Text(
                                  c.sourceId,
                                  style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
