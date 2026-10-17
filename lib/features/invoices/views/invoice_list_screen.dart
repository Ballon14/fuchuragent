import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/invoice_model.dart';
import 'invoice_form_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/app_card.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  String _searchQuery = '';

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
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.post_add_rounded),
              label: const Text('Buat Tagihan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: StreamBuilder<List<InvoiceModel>>(
        stream: invoiceRepo.watchInvoices(statusFilter: _statusFilter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          var invoices = snapshot.data ?? [];
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            invoices = invoices.where((i) => i.invoiceNumber.toLowerCase().contains(q)).toList();
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
                          DropdownMenuItem(value: 'unpaid', child: Text('Belum Dibayar')),
                          DropdownMenuItem(value: 'partial', child: Text('Dibayar Sebagian')),
                          DropdownMenuItem(value: 'paid', child: Text('Lunas')),
                          DropdownMenuItem(value: 'overdue', child: Text('Terlambat')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _statusFilter = val);
                        },
                      ),
                      Text(
                        'Menampilkan ${invoices.length} Tagihan',
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
                      : (isDesktop ? _buildDesktopTable(invoices) : _buildMobileList(invoices)),
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
        hintText: 'Cari nomor tagihan (misal: INV-202607)...',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final isSelected = _statusFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _statusFilter = value);
      },
      selectedColor: primaryColor.withValues(alpha: isDark ? 0.2 : 0.12),
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
          const Text('Belum ada tagihan yang ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Terbitkan tagihan baru untuk layanan VPS pelanggan FuchurHost.',
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

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Nomor Tagihan')),
              DataColumn(label: Text('Item Layanan')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Dibayar')),
              DataColumn(label: Text('Sisa Saldo')),
              DataColumn(label: Text('Jatuh Tempo')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: list.map((inv) {
              return DataRow(
                cells: [
                  DataCell(Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(
                    Text(
                      inv.items.map((i) => i.description).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(Text(AppConstants.formatRupiah(inv.total), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(AppConstants.formatRupiah(inv.paidAmount), style: const TextStyle(color: AppColors.success))),
                  DataCell(
                    Text(
                      AppConstants.formatRupiah(inv.remainingBalance),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: inv.remainingBalance > 0 ? AppColors.warning : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  DataCell(Text(AppConstants.formatShortDate(inv.dueDate))),
                  DataCell(StatusBadge(status: inv.isOverdue ? 'overdue' : inv.status)),
                  DataCell(
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, color: primaryColor),
                      onPressed: () => context.go('/invoices/${inv.id}'),
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
