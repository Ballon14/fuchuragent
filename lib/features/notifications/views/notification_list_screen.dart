import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../services/local_notification_service.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/app_pagination_bar.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends ConsumerState<NotificationListScreen> {
  String _selectedFilter = 'ALL'; // 'ALL', 'UNREAD', 'EXPIRATION', 'FINANCE', 'SYSTEM'
  bool _isSyncing = false;
  bool? _isPermissionGranted;
  int _currentPage = 1;
  int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await LocalNotificationService().areNotificationsEnabled();
    if (mounted) {
      setState(() => _isPermissionGranted = granted);
    }
  }

  Future<void> _requestPermission() async {
    final granted = await LocalNotificationService().requestPermission();
    if (mounted) {
      setState(() => _isPermissionGranted = granted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted
              ? 'Izin notifikasi sistem berhasil diaktifkan!'
              : 'Izin notifikasi belum diaktifkan. Buka Pengaturan Perangkat untuk mengizinkan.'),
          backgroundColor: granted ? AppColors.success : AppColors.warning,
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    await LocalNotificationService().showTestNotification();
    await _checkPermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifikasi uji coba telah dikirim ke status bar / tray sistem!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showBackgroundInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_charging_full_rounded, color: AppColors.cyan),
            SizedBox(width: 8),
            Text('Izin Latar Belakang'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agar notifikasi peringatan VPS & tagihan dapat muncul saat aplikasi tidak dibuka:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• Android: Buka Pengaturan HP > Aplikasi > Fuchur Agent > Baterai / Penggunaan Daya > Pilih "Tidak Dibatasi" (Unrestricted).'),
            SizedBox(height: 8),
            Text('• Android 13+: Izinkan "Notifikasi" saat dialog izin sistem muncul.'),
            SizedBox(height: 8),
            Text('• Windows: Pastikan "Notifikasi & Tindakan" (Notifications & Actions) aktif di Windows Settings.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final notifRepo = ref.read(notificationRepositoryProvider);
      final newCount = await notifRepo.syncSystemAlerts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceDark,
            content: Text(
              newCount > 0
                  ? 'Sinkronisasi selesai: $newCount peringatan baru terdeteksi!'
                  : 'Sistem telah diperiksa. Tidak ada peringatan baru yang memerlukan perhatian.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Gagal menyinkronkan peringatan: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifRepo = ref.watch(notificationRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifikasi & Peringatan'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sinkronkan & Cek Peringatan',
            onPressed: _isSyncing ? null : _handleSync,
          ),
          TextButton.icon(
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Tandai Dibaca'),
            onPressed: () async {
              await notifRepo.markAllAsRead();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua notifikasi telah ditandai dibaca.')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Opsi Lainnya',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              if (val == 'clear_read') {
                final confirmed = await ConfirmationDialog.showDeleteConfirmation(
                  context: context,
                  title: 'Bersihkan Notifikasi',
                  itemName: 'Semua Notifikasi Yang Telah Dibaca',
                  detail: 'Pemberitahuan yang sudah dibaca akan dihapus secara permanen.',
                );
                if (!confirmed || !context.mounted) return;

                await notifRepo.clearReadNotifications();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifikasi yang sudah dibaca telah dibersihkan.')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_read',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Bersihkan Yang Telah Dibaca'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Banner Status Izin Notifikasi Sistem (Android & Windows)
          _buildSystemPermissionBanner(isDark, primaryAccent),

          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua', 'ALL', Icons.all_inbox_rounded, primaryAccent, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Belum Dibaca', 'UNREAD', Icons.mark_email_unread_rounded, AppColors.electricBlue, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Kedaluwarsa', 'EXPIRATION', Icons.timer_rounded, AppColors.warning, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Tagihan & Bayar', 'FINANCE', Icons.receipt_long_rounded, AppColors.success, isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Sistem & Pelanggan', 'SYSTEM', Icons.dns_rounded, AppColors.cyan, isDark),
                ],
              ),
            ),
          ),

          // Notification List Stream
          Expanded(
            child: StreamBuilder<List<AppNotificationModel>>(
              stream: notifRepo.watchNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.cyan),
                  );
                }

                var notifications = snapshot.data ?? [];

                // Filter in-memory according to active tab
                if (_selectedFilter == 'UNREAD') {
                  notifications = notifications.where((n) => !n.isRead).toList();
                } else if (_selectedFilter == 'EXPIRATION') {
                  notifications = notifications.where((n) => n.category.toUpperCase() == 'EXPIRATION').toList();
                } else if (_selectedFilter == 'FINANCE') {
                  notifications = notifications.where((n) =>
                      n.category.toUpperCase() == 'INVOICE' ||
                      n.category.toUpperCase() == 'PAYMENT').toList();
                } else if (_selectedFilter == 'SYSTEM') {
                  notifications = notifications.where((n) => n.category.toUpperCase() == 'SYSTEM').toList();
                }

                if (notifications.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFilter == 'ALL'
                                ? 'Tidak ada notifikasi.'
                                : 'Tidak ada notifikasi pada kategori ini.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sistem akan otomatis memantau masa aktif VPS, tagihan jatuh tempo, dan transaksi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.sync_rounded, size: 16),
                            label: const Text('Cek Peringatan Sekarang'),
                            onPressed: _handleSync,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final totalItems = notifications.length;
                final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
                final safeCurrentPage = _currentPage.clamp(1, totalPages);
                final startIndex = (safeCurrentPage - 1) * _itemsPerPage;
                final pageNotifications = notifications.skip(startIndex).take(_itemsPerPage).toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: pageNotifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final n = pageNotifications[idx];
                          return _buildNotificationCard(context, n, notifRepo, isDark, primaryAccent);
                        },
                      ),
                    ),
                    if (totalItems > _itemsPerPage) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: AppPaginationBar(
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
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    IconData icon,
    Color activeColor,
    bool isDark,
  ) {
    final isSelected = _selectedFilter == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = value;
          _currentPage = 1;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.2 : 0.12)
              : (isDark ? AppColors.surfaceLightDark.withValues(alpha: 0.3) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : activeColor)
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotificationModel n,
    NotificationRepository notifRepo,
    bool isDark,
    Color primaryAccent,
  ) {
    Color iconColor;
    IconData iconData;
    String badgeLabel;

    switch (n.category.toUpperCase()) {
      case 'EXPIRATION':
        iconColor = AppColors.warning;
        iconData = Icons.timer_rounded;
        badgeLabel = 'Kedaluwarsa';
        break;
      case 'PAYMENT':
        iconColor = AppColors.success;
        iconData = Icons.payments_rounded;
        badgeLabel = 'Pembayaran';
        break;
      case 'INVOICE':
        iconColor = AppColors.electricBlue;
        iconData = Icons.receipt_long_rounded;
        badgeLabel = 'Tagihan';
        break;
      default:
        iconColor = AppColors.cyan;
        iconData = Icons.dns_rounded;
        badgeLabel = 'Sistem';
    }

    final cardBg = !n.isRead
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF))
        : (isDark ? AppColors.surfaceDark.withValues(alpha: 0.7) : Colors.white);

    final borderColor = !n.isRead
        ? (isDark ? AppColors.cyan.withValues(alpha: 0.4) : const Color(0xFF0284C7).withValues(alpha: 0.35))
        : (isDark ? AppColors.borderDark.withValues(alpha: 0.5) : AppColors.borderLight);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!n.isRead) {
            notifRepo.markAsRead(n.id);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: !n.isRead ? 1.5 : 1),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon
              CircleAvatar(
                radius: 18,
                backgroundColor: iconColor.withValues(alpha: 0.15),
                child: Icon(iconData, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),

              // Content Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Title + Category Badge + Unread Dot
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: primaryAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Message Body
                    Text(
                      n.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Footer: Timestamp + Delete action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppConstants.formatDateTime(n.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!n.isRead)
                              InkWell(
                                onTap: () => notifRepo.markAsRead(n.id),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    'Tandai telah dibaca',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: primaryAccent,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () async {
                                final confirmed = await ConfirmationDialog.showDeleteConfirmation(
                                  context: context,
                                  title: 'Hapus Notifikasi',
                                  itemName: n.title,
                                  detail: n.message,
                                );
                                if (!confirmed) return;
                                await notifRepo.deleteNotification(n.id);
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemPermissionBanner(bool isDark, Color primaryAccent) {
    final granted = _isPermissionGranted;

    if (granted == false) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.1),
          border: Border(
            bottom: BorderSide(
              color: AppColors.warning.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off_rounded, size: 20, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Izin Notifikasi Sistem Belum Aktif',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Aktifkan agar peringatan VPS & tagihan muncul di status bar Android dan desktop Windows.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _requestPermission,
              child: const Text('Izinkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              tooltip: 'Petunjuk Latar Belakang',
              onPressed: _showBackgroundInfoDialog,
            ),
          ],
        ),
      );
    }

    // When granted (or checking)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceLightDark : const Color(0xFFF8FAFC)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Notifikasi Sistem & Latar Belakang Aktif',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            icon: const Icon(Icons.send_rounded, size: 12),
            label: const Text('Uji Notifikasi', style: TextStyle(fontSize: 11)),
            onPressed: _sendTestNotification,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 16),
            tooltip: 'Panduan Latar Belakang (Android/Windows)',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: _showBackgroundInfoDialog,
          ),
        ],
      ),
    );
  }
}
