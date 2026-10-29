import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/invoice_model.dart';
import 'invoice_form_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_pagination_bar.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  String _searchQuery = '';
  int _currentPage = 1;
  int _itemsPerPage = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final inv = await InvoiceFormDialog.show(context);
    if (inv != null) {
      await ref.read(invoiceRepositoryProvider).createInvoice(
            customerId: inv.customerId,
            serviceId: inv.serviceId,
            items: inv.items,
            discount: inv.discount,
            dueDate: inv.dueDate,
            notes: inv.notes,
          );
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tagihan baru berhasil dibuat.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoiceRepo = ref.watch(invoiceRepositoryProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Tagihan'),
        actions: [
          if (isDesktop)
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Buat Tagihan'),
              onPressed: _openCreateDialog,
            )
          else
            IconButton(
              icon: const Icon(Icons.post_add_rounded),
              tooltip: 'Buat Tagihan',
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
              icon: const Icon(Icons.post_add_rounded),
              label: const Text('Buat Tagihan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: StreamBuilder<List<InvoiceModel>>(
        stream: invoiceRepo.watchInvoices(statusFilter: _statusFilter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          var invoices = snapshot.data ?? [];
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            invoices = invoices.where((i) => i.invoiceNumber.toLowerCase().contains(q)).toList();
          }

          final totalItems = invoices.length;
          final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
          final safeCurrentPage = _currentPage.clamp(1, totalPages);
          final startIndex = (safeCurrentPage - 1) * _itemsPerPage;
          final pageInvoices = invoices.skip(startIndex).take(_itemsPerPage).toList();

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
                              DropdownMenuItem(value: 'unpaid', child: Text('Belum Dibayar')),
                              DropdownMenuItem(value: 'partial', child: Text('Dibayar Sebagian')),
                              DropdownMenuItem(value: 'paid', child: Text('Lunas')),
                              DropdownMenuItem(value: 'overdue', child: Text('Terlambat')),
                              DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
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
                            ? 'Total $totalItems Tagihan (Hal. $safeCurrentPage/$totalPages)'
                            : 'Menampilkan $totalItems Tagihan',
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
                        _buildFilterChip('all', 'Semua (${invoices.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('unpaid', 'Belum Lunas'),
                        const SizedBox(width: 8),
                        _buildFilterChip('partial', 'Sebagian'),
                        const SizedBox(width: 8),
                        _buildFilterChip('paid', 'Lunas'),
                        const SizedBox(width: 8),
                        _buildFilterChip('overdue', 'Terlambat'),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: isDesktop ? 20 : 14),

                // Content
                Expanded(
                  child: invoices.isEmpty
                      ? _buildEmptyState()
                      : (isDesktop ? _buildDesktopTable(pageInvoices) : _buildMobileList(pageInvoices)),
                ),

                // Pagination Bar (Only when data exceeds itemsPerPage)
                if (totalItems > _itemsPerPage) ...[
                  const SizedBox(height: 14),
                  AppPaginationBar(
                    currentPage: safeCurrentPage,
                    totalItems: totalItems,
                    itemsPerPage: _itemsPerPage,
                    hasBottomFab: !isDesktop,
                    availableItemsPerPage: const [10, 20, 50],
                    onPageChanged: (newPage) {
                      setState(() => _currentPage = newPage);
                    },
                    onItemsPerPageChanged: (newLimit) {
                      setState(() {
                        _itemsPerPage = newLimit;
                        _currentPage = 1;
                      });
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
        hintText: 'Cari nomor tagihan (misal: INV-202607)...',
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
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('Belum ada tagihan yang ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Terbitkan tagihan baru untuk layanan VPS pelanggan.',
            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Buat Tagihan Baru'),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<InvoiceModel> list) {
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
                Expanded(flex: 3, child: Text('NOMOR TAGIHAN', style: headerStyle)),
                Expanded(flex: 4, child: Text('ITEM LAYANAN', style: headerStyle)),
                Expanded(flex: 2, child: Text('TOTAL', style: headerStyle)),
                Expanded(flex: 2, child: Text('DIBAYAR', style: headerStyle)),
                Expanded(flex: 2, child: Text('SISA SALDO', style: headerStyle)),
                Expanded(flex: 2, child: Text('JATUH TEMPO', style: headerStyle)),
                Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
                SizedBox(
                  width: 44,
                  child: Center(child: Text('AKSI', style: headerStyle)),
                ),
              ],
            ),
          ),

          // Daftar Baris Tagihan (Pas satu layar, interaktif dengan hover)
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.borderLight,
              ),
              itemBuilder: (context, idx) {
                final inv = list[idx];
                return InkWell(
                  onTap: () => context.go('/invoices/${inv.id}'),
                  hoverColor: primaryColor.withValues(alpha: 0.05),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Nomor Tagihan
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.receipt_long_rounded, size: 14, color: primaryColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  inv.invoiceNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Item Layanan
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              inv.items.map((i) => i.description).join(', '),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // Total
                        Expanded(
                          flex: 2,
                          child: Text(
                            AppConstants.formatRupiah(inv.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Dibayar
                        Expanded(
                          flex: 2,
                          child: Text(
                            AppConstants.formatRupiah(inv.paidAmount),
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Sisa Saldo
                        Expanded(
                          flex: 2,
                          child: Text(
                            AppConstants.formatRupiah(inv.remainingBalance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: inv.remainingBalance > 0
                                  ? AppColors.warning
                                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Jatuh Tempo
                        Expanded(
                          flex: 2,
                          child: Text(
                            AppConstants.formatShortDate(inv.dueDate),
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Status
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(status: inv.isOverdue ? 'overdue' : inv.status),
                          ),
                        ),

                        // Aksi
                        SizedBox(
                          width: 44,
                          child: IconButton(
                            icon: Icon(Icons.chevron_right_rounded, color: primaryColor, size: 20),
                            tooltip: 'Detail Tagihan',
                            onPressed: () => context.go('/invoices/${inv.id}'),
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

  Widget _buildMobileList(List<InvoiceModel> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final inv = list[idx];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/invoices/${inv.id}'),
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
                          color: AppColors.electricBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_rounded, color: AppColors.electricBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.invoiceNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total: ${AppConstants.formatRupiah(inv.total)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: inv.isOverdue ? 'overdue' : inv.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sisa: ${AppConstants.formatRupiah(inv.remainingBalance)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: inv.remainingBalance > 0 ? AppColors.warning : AppColors.success,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Jatuh Tempo: ${AppConstants.formatShortDate(inv.dueDate)}',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                          ),
                        ],
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
