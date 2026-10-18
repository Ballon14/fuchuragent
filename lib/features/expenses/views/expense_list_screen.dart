import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/expense_model.dart';
import 'expense_form_dialog.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/app_pagination_bar.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'all';
  int _currentPage = 1;
  int _itemsPerPage = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final res = await ExpenseFormDialog.show(context);
    if (res != null && mounted) {
      ref.invalidate(dashboardStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengeluaran ${res.expenseNumber} berhasil dicatat.')),
      );
    }
  }

  Future<void> _openEditDialog(ExpenseModel expense) async {
    final res = await ExpenseFormDialog.show(context, expense: expense);
    if (res != null && mounted) {
      ref.invalidate(dashboardStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pengeluaran ${res.expenseNumber} berhasil diperbarui.')),
      );
    }
  }

  Future<void> _handleDelete(ExpenseModel expense) async {
    final confirmed = await ConfirmationDialog.showDeleteConfirmation(
      context: context,
      title: 'Hapus Catatan Pengeluaran',
      itemName: expense.title,
      detail: 'Nominal: ${AppConstants.formatRupiah(expense.amount)} | Kategori: ${expense.category}',
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
        ref.invalidate(dashboardStatsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengeluaran berhasil dihapus.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus pengeluaran: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseRepo = ref.watch(expenseRepositoryProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pengeluaran Operasional'),
        actions: [
          if (isDesktop)
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Catat Pengeluaran'),
              onPressed: _openCreateDialog,
            )
          else
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Catat Pengeluaran',
              onPressed: _openCreateDialog,
            ),
          const SizedBox(width: 14),
        ],
      ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateDialog,
              backgroundColor: primaryAccent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Catat Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: expenseRepo.watchExpenses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final allExpenses = snapshot.data ?? [];

          // Filter by category
          var filtered = allExpenses;
          if (_categoryFilter != 'all') {
            filtered = filtered.where((e) => e.category.toLowerCase() == _categoryFilter.toLowerCase()).toList();
          }

          // Filter by search query
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            filtered = filtered.where((e) {
              return e.title.toLowerCase().contains(q) ||
                  e.expenseNumber.toLowerCase().contains(q) ||
                  e.recipient.toLowerCase().contains(q) ||
                  e.categoryLabel.toLowerCase().contains(q) ||
                  e.paymentMethod.toLowerCase().contains(q) ||
                  e.notes.toLowerCase().contains(q);
            }).toList();
          }

          // KPI Stats
          final totalExpensesAmount = allExpenses.fold<int>(0, (sum, e) => sum + e.amount);
          final filteredExpensesAmount = filtered.fold<int>(0, (sum, e) => sum + e.amount);

          // Pagination logic
          final totalItems = filtered.length;
          final totalPages = (totalItems / _itemsPerPage).ceil().clamp(1, 9999);
          final safeCurrentPage = _currentPage.clamp(1, totalPages);
          final startIndex = (safeCurrentPage - 1) * _itemsPerPage;
          final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
          final pageExpenses = totalItems > 0 ? filtered.sublist(startIndex, endIndex) : <ExpenseModel>[];

          return Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Summary Cards
                _buildSummaryKpi(context, isDesktop, allExpenses.length, totalExpensesAmount, filteredExpensesAmount),
                SizedBox(height: isDesktop ? 20 : 14),

                // Search & Filter Bar
                _buildSearchAndFilterBar(isDesktop),
                SizedBox(height: isDesktop ? 16 : 10),

                // Table or List Content
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : (isDesktop ? _buildDesktopTable(pageExpenses) : _buildMobileList(pageExpenses)),
                ),

                // Pagination Bar
                if (totalItems > _itemsPerPage) ...[
                  const SizedBox(height: 14),
                  AppPaginationBar(
                    currentPage: safeCurrentPage,
                    totalItems: totalItems,
                    itemsPerPage: _itemsPerPage,
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

  Widget _buildSummaryKpi(
    BuildContext context,
    bool isDesktop,
    int totalCount,
    int totalAmount,
    int filteredAmount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: width > 600 ? 14 : 10,
          mainAxisSpacing: width > 600 ? 14 : 10,
          childAspectRatio: width > 900 ? 2.6 : (width > 600 ? 2.4 : 3.2),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Total Kas Keluar (Semua)',
              value: AppConstants.formatRupiah(totalAmount),
              subtitle: '$totalCount Transaksi Pengeluaran Tercatat',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: AppColors.danger,
            ),
            StatCard(
              title: _categoryFilter == 'all' ? 'Hasil Filter / Pencarian' : 'Total Kategori Terpilih',
              value: AppConstants.formatRupiah(filteredAmount),
              subtitle: _categoryFilter == 'all'
                  ? 'Menampilkan semua kategori biaya'
                  : 'Filter kategori: ${_getCategoryLabel(_categoryFilter)}',
              icon: Icons.filter_alt_rounded,
              accentColor: AppColors.warning,
            ),
            if (width > 900)
              StatCard(
                title: 'Kategori Operasional Utama',
                value: 'Server, Worker & Lisensi',
                subtitle: 'Pencatatan sequential EXP-xxx realtime',
                icon: Icons.category_rounded,
                accentColor: AppColors.cyan,
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilterBar(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari judul, nomor EXP, vendor, atau catatan...',
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'Semua Kategori'),
              const SizedBox(width: 8),
              _buildFilterChip('SERVER', 'Server & Infra'),
              const SizedBox(width: 8),
              _buildFilterChip('WORKER', 'Upah Worker'),
              const SizedBox(width: 8),
              _buildFilterChip('LICENSE', 'Lisensi Software'),
              const SizedBox(width: 8),
              _buildFilterChip('DOMAIN', 'Domain & SSL'),
              const SizedBox(width: 8),
              _buildFilterChip('NETWORK', 'Jaringan'),
              const SizedBox(width: 8),
              _buildFilterChip('OPERATIONAL', 'Operasional'),
              const SizedBox(width: 8),
              _buildFilterChip('OTHER', 'Lain-lain'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final isSelected = _categoryFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _categoryFilter = value;
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
          Icon(Icons.receipt_long_rounded, size: 64, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('Belum ada data pengeluaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _categoryFilter != 'all'
                ? 'Tidak ada pengeluaran yang sesuai dengan kriteria filter Anda.'
                : 'Catat biaya server, lisensi, atau upah worker untuk merekap kas keluar.',
            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Catat Pengeluaran Baru'),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
    );
  }

  /// Full-width flex table for Windows Desktop without horizontal scroll drag
  Widget _buildDesktopTable(List<ExpenseModel> list) {
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
          // Table Header (Full Width 100%, without horizontal scrolling)
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
                Expanded(flex: 2, child: Text('NO. PENGELUARAN', style: headerStyle)),
                Expanded(flex: 4, child: Text('JUDUL & KEPERLUAN', style: headerStyle)),
                Expanded(flex: 3, child: Text('KATEGORI', style: headerStyle)),
                Expanded(flex: 3, child: Text('NOMINAL (IDR)', style: headerStyle)),
                Expanded(flex: 3, child: Text('TANGGAL & PENERIMA', style: headerStyle)),
                Expanded(flex: 3, child: Text('METODE BAYAR', style: headerStyle)),
                SizedBox(
                  width: 72,
                  child: Center(child: Text('AKSI', style: headerStyle)),
                ),
              ],
            ),
          ),

          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 1,
                color: isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.borderLight,
              ),
              itemBuilder: (context, idx) {
                final e = list[idx];
                return InkWell(
                  onTap: () => _openEditDialog(e),
                  hoverColor: primaryColor.withValues(alpha: 0.05),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // No. Pengeluaran
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  e.expenseNumber.isNotEmpty ? e.expenseNumber : 'EXP-${idx + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Judul & Catatan
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  e.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (e.notes.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    e.notes,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Kategori
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: e.categoryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: e.categoryColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(e.categoryIcon, size: 13, color: e.categoryColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      e.categoryLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: e.categoryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Nominal
                        Expanded(
                          flex: 3,
                          child: Text(
                            AppConstants.formatRupiah(e.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.danger,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Tanggal & Penerima
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppConstants.formatShortDate(e.expenseDate),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              if (e.recipient.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  e.recipient,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Metode Pembayaran
                        Expanded(
                          flex: 3,
                          child: Text(
                            e.paymentMethod,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Aksi (Edit & Hapus)
                        SizedBox(
                          width: 72,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                tooltip: 'Edit',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () => _openEditDialog(e),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                tooltip: 'Hapus',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () => _handleDelete(e),
                              ),
                            ],
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

  /// Responsive card list for mobile (< 900px)
  Widget _buildMobileList(List<ExpenseModel> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final e = list[idx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openEditDialog(e),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: e.categoryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(e.categoryIcon, size: 18, color: e.categoryColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  e.expenseNumber.isNotEmpty ? e.expenseNumber : 'EXP-${idx + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  AppConstants.formatShortDate(e.expenseDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              e.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Penerima: ${e.recipient.isNotEmpty ? e.recipient : '-'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.paymentMethod,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        AppConstants.formatRupiah(e.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  if (e.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Catatan: ${e.notes}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getCategoryLabel(String cat) {
    final m = ExpenseModel(id: '', title: '', category: cat, amount: 0, expenseDate: DateTime.now());
    return m.categoryLabel;
  }
}
