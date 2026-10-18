import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/activity_log_model.dart';
import '../repositories/audit_repository.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_pagination_bar.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _categoryFilter = 'all';
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
  bool _isTestingLog = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String cat) {
    setState(() {
      _categoryFilter = cat;
      _currentPage = 1;
    });
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      _currentPage = 1;
    });
  }

  Future<void> _handleTestLog() async {
    if (_isTestingLog) return;
    setState(() => _isTestingLog = true);

    try {
      final auditRepo = ref.read(auditRepositoryProvider);
      final profile = ref.read(currentUserProfileProvider).value;
      final actorName = profile?.name ?? profile?.email ?? 'Administrator';

      await auditRepo.logActivity(
        action: 'TEST_AUDIT_VERIFICATION',
        category: 'SECURITY',
        details: 'Uji verifikasi sistem audit trail dijalankan oleh $actorName. Fitur pencatatan riwayat operasional berfungsi normal.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Uji log audit berhasil dicatat ke sistem!'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Gagal mencatat log uji: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingLog = false);
      }
    }
  }

  void _showLogDetailsDialog(BuildContext context, ActivityLogModel log, bool isDark) {
    final meta = _getCategoryMeta(log.category);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: meta.color.withValues(alpha: 0.15),
                child: Icon(meta.icon, color: meta.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatActionLabel(log.action),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Kategori: ${log.category}',
                      style: TextStyle(fontSize: 11, color: meta.color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Deskripsi Aktivitas', log.details, isDark, isHighlight: true),
                const SizedBox(height: 12),
                _buildDetailRow('Pelaksana (Aktor)', '${log.actorName} (${log.actorId})', isDark),
                const SizedBox(height: 12),
                _buildDetailRow('Waktu Pencatatan', AppConstants.formatDateTime(log.timestamp), isDark),
                if (log.targetId != null && log.targetId!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Target Terkait (ID)', log.targetId!, isDark, canCopy: true),
                ],
                const SizedBox(height: 12),
                _buildDetailRow('ID Log Firestore', log.id, isDark, canCopy: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isHighlight = false, bool canCopy = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (canCopy)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14),
                tooltip: 'Salin',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      content: Text('$label berhasil disalin'),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auditRepo = ref.watch(auditRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Audit Trail & Log Aktivitas Sistem'),
        actions: [
          TextButton.icon(
            icon: _isTestingLog
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                  )
                : const Icon(Icons.playlist_add_check_rounded, size: 18),
            label: const Text('Uji Catat Log'),
            onPressed: _isTestingLog ? null : _handleTestLog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<ActivityLogModel>>(
        stream: auditRepo.watchLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryAccent));
          }

          final allLogs = snapshot.data ?? [];
          final filteredLogs = AuditRepository.filterLogs(
            allLogs,
            categoryFilter: _categoryFilter,
            searchQuery: _searchQuery,
          );

          // Paginasi: 10 item per halaman
          final totalItems = filteredLogs.length;
          final maxPage = ((totalItems - 1) ~/ _itemsPerPage) + 1;
          final safeCurrentPage = _currentPage > maxPage ? (maxPage > 0 ? maxPage : 1) : _currentPage;
          final startIndex = (safeCurrentPage - 1) * _itemsPerPage;
          final pagedLogs = filteredLogs.skip(startIndex).take(_itemsPerPage).toList();

          return Column(
            children: [
              // Search & Filter Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Input
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Cari log aktivitas (aksi, pengguna, target, detail)...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceLightDark.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Semua Kategori', 'all', primaryAccent, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Keuangan', 'FINANCE', AppColors.success, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Layanan VPS', 'SERVICES', AppColors.electricBlue, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pelanggan', 'CUSTOMERS', const Color(0xFFA855F7), isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Keamanan & Akun', 'SECURITY', AppColors.warning, isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Paket VPS', 'PACKAGES', const Color(0xFF6366F1), isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip('Impor Data', 'IMPORT', AppColors.cyan, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content List
              Expanded(
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 56,
                              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ada log aktivitas yang cocok dengan pencarian.'
                                  : 'Belum ada log aktivitas pada kategori ini.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Setiap penambahan pelanggan, perubahan status VPS, tagihan, dan pembayaran akan dicatat di sini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
                              label: const Text('Buat Log Uji Sekarang'),
                              onPressed: _handleTestLog,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: pagedLogs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final log = pagedLogs[idx];
                          final meta = _getCategoryMeta(log.category);

                          return AppCard(
                            padding: const EdgeInsets.all(14),
                            child: InkWell(
                              onTap: () => _showLogDetailsDialog(context, log, isDark),
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: meta.color.withValues(alpha: 0.15),
                                    child: Icon(meta.icon, color: meta.color, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Row: Category badge, Action label, Timestamp
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: meta.color.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                log.category,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: meta.color,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _formatActionLabel(log.action),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              AppConstants.formatDateTime(log.timestamp),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Details
                                        Text(
                                          log.details,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Footer: Actor name & Target ID
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.person_outline_rounded,
                                                  size: 13,
                                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  log.actorName,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (log.targetId != null && log.targetId!.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? AppColors.surfaceLightDark.withValues(alpha: 0.5)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'ID: ${log.targetId!.substring(0, log.targetId!.length > 10 ? 10 : log.targetId!.length)}',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontFamily: 'monospace',
                                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                          ],
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

              // Pagination Bar (10 per page)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                ),
                child: AppPaginationBar(
                  currentPage: safeCurrentPage,
                  totalItems: totalItems,
                  itemsPerPage: _itemsPerPage,
                  alwaysShow: true,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color, bool isDark) {
    final isSelected = _categoryFilter == value;

    return InkWell(
      onTap: () => _onCategorySelected(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark ? AppColors.surfaceLightDark.withValues(alpha: 0.3) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : color)
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  _CategoryMeta _getCategoryMeta(String category) {
    switch (category.toUpperCase()) {
      case 'FINANCE':
        return _CategoryMeta(color: AppColors.success, icon: Icons.payments_rounded);
      case 'SERVICES':
        return _CategoryMeta(color: AppColors.electricBlue, icon: Icons.dns_rounded);
      case 'CUSTOMERS':
        return _CategoryMeta(color: const Color(0xFFA855F7), icon: Icons.people_alt_rounded);
      case 'SECURITY':
        return _CategoryMeta(color: AppColors.warning, icon: Icons.admin_panel_settings_rounded);
      case 'PACKAGES':
        return _CategoryMeta(color: const Color(0xFF6366F1), icon: Icons.inventory_2_rounded);
      case 'IMPORT':
        return _CategoryMeta(color: AppColors.cyan, icon: Icons.file_upload_rounded);
      default:
        return _CategoryMeta(color: AppColors.cyan, icon: Icons.history_edu_rounded);
    }
  }

  String _formatActionLabel(String action) {
    switch (action.toUpperCase()) {
      case 'CREATE_CUSTOMER':
        return 'Tambah Pelanggan';
      case 'UPDATE_CUSTOMER':
        return 'Perbarui Pelanggan';
      case 'DELETE_CUSTOMER':
        return 'Hapus Pelanggan';
      case 'CREATE_SERVICE':
        return 'Buat Layanan VPS';
      case 'UPDATE_SERVICE':
        return 'Perbarui Layanan VPS';
      case 'CREATE_INVOICE':
        return 'Terbitkan Tagihan';
      case 'CANCEL_INVOICE':
        return 'Batalkan Tagihan';
      case 'RECORD_PAYMENT':
        return 'Catat Pembayaran';
      case 'REVERSE_PAYMENT':
        return 'Batalkan Pembayaran';
      case 'RENEW_SERVICE':
        return 'Perpanjang Layanan VPS';
      case 'UPDATE_ROLE':
        return 'Ubah Hak Akses Pengguna';
      case 'TOGGLE_USER_STATUS':
        return 'Ubah Status Akun Pengguna';
      case 'IMPORT_CSV':
        return 'Impor Data Spreadsheet';
      case 'TEST_AUDIT_VERIFICATION':
        return 'Verifikasi Audit Log';
      default:
        return action;
    }
  }
}

class _CategoryMeta {
  final Color color;
  final IconData icon;

  const _CategoryMeta({required this.color, required this.icon});
}
