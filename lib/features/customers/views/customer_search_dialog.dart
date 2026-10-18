import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/customer_model.dart';
import 'customer_form_dialog.dart';
import '../../../shared/widgets/status_badge.dart';

class CustomerSearchDialog extends ConsumerStatefulWidget {
  final String? selectedCustomerId;

  const CustomerSearchDialog({super.key, this.selectedCustomerId});

  static Future<CustomerModel?> show(BuildContext context, {String? selectedCustomerId}) {
    return showDialog<CustomerModel>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomerSearchDialog(selectedCustomerId: selectedCustomerId),
    );
  }

  @override
  ConsumerState<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends ConsumerState<CustomerSearchDialog> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createNewCustomer() async {
    final newCust = await CustomerFormDialog.show(context);
    if (newCust != null && mounted) {
      final docId = await ref.read(customerRepositoryProvider).addCustomer(newCust);
      if (mounted) {
        final createdCustomer = newCust.copyWith(id: docId);
        Navigator.of(context).pop(createdCustomer);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerRepositoryProvider).watchCustomers();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_search_rounded, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cari & Pilih Pelanggan',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pilih pelanggan berdasarkan nama, WhatsApp, atau ID',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Tutup',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search input
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ketik nama, WhatsApp, ID (misal: Cus-020)...',
                  prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
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
              ),
              const SizedBox(height: 10),

              // Filter Chips & Quick Add button
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'Semua'),
                          const SizedBox(width: 6),
                          _buildFilterChip('active', 'Aktif'),
                          const SizedBox(width: 6),
                          _buildFilterChip('inactive', 'Nonaktif'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _createNewCustomer,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Pelanggan Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Results Stream
              Expanded(
                child: StreamBuilder<List<CustomerModel>>(
                  stream: customersAsync,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Gagal memuat pelanggan: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      );
                    }

                    var list = snapshot.data ?? [];

                    // Filter status
                    if (_statusFilter != 'all') {
                      list = list.where((c) => c.status.toLowerCase() == _statusFilter).toList();
                    }

                    // Search query filter
                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      list = list.where((c) {
                        return c.name.toLowerCase().contains(q) ||
                            c.phone.contains(q) ||
                            c.sourceId.toLowerCase().contains(q) ||
                            (c.email?.toLowerCase().contains(q) ?? false);
                      }).toList();
                    }

                    if (list.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                size: 48,
                                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tidak ada pelanggan cocok dengan "$_searchQuery"'
                                    : 'Belum ada data pelanggan',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _createNewCustomer,
                                icon: const Icon(Icons.person_add_rounded, size: 16),
                                label: const Text('Tambah Pelanggan Baru'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Ditemukan ${list.length} pelanggan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final c = list[idx];
                              final isSelected = c.id == widget.selectedCustomerId;

                              return InkWell(
                                onTap: () => Navigator.of(context).pop(c),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
                                        : (isDark ? AppColors.surfaceLightDark.withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: primaryColor.withValues(alpha: 0.18),
                                        child: Text(
                                          c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    c.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (c.sourceId.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: primaryColor.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      c.sourceId,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: primaryColor,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.phone_rounded,
                                                  size: 12,
                                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  c.phone,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                StatusBadge(status: c.status),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isSelected)
                                        Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
                                      else
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
      backgroundColor: isDark ? AppColors.surfaceLightDark : Colors.white,
      selectedColor: primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
      side: BorderSide(
        color: isSelected ? primaryColor : (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
    );
  }
}
