import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../features/notifications/services/local_notification_service.dart';
import 'confirmation_dialog.dart';

class NavItem {
  final String title;
  final IconData icon;
  final String route;
  final bool adminOnly;

  const NavItem({
    required this.title,
    required this.icon,
    required this.route,
    this.adminOnly = false,
  });
}

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  static const List<NavItem> navItems = [
    NavItem(title: 'Dashboard', icon: Icons.dashboard_rounded, route: '/'),
    NavItem(title: 'Pelanggan', icon: Icons.people_alt_rounded, route: '/customers'),
    NavItem(title: 'Layanan VPS', icon: Icons.dns_rounded, route: '/services'),
    NavItem(title: 'Paket VPS', icon: Icons.inventory_2_rounded, route: '/packages'),
    NavItem(title: 'Tagihan', icon: Icons.receipt_long_rounded, route: '/invoices'),
    NavItem(title: 'Pembayaran', icon: Icons.payments_rounded, route: '/payments'),
    NavItem(title: 'Kelola Pengeluaran', icon: Icons.account_balance_wallet_rounded, route: '/expenses'),
    NavItem(title: 'Keuangan', icon: Icons.analytics_rounded, route: '/finance'),
    NavItem(title: 'Perpanjangan', icon: Icons.autorenew_rounded, route: '/renewals'),
    NavItem(title: 'Laporan', icon: Icons.bar_chart_rounded, route: '/reports'),
    NavItem(title: 'Notifikasi', icon: Icons.notifications_rounded, route: '/notifications'),
    NavItem(title: 'Pengguna', icon: Icons.manage_accounts_rounded, route: '/users', adminOnly: true),
    NavItem(title: 'Audit Log', icon: Icons.history_edu_rounded, route: '/audit', adminOnly: true),
    NavItem(title: 'Pengaturan', icon: Icons.settings_rounded, route: '/settings'),
    NavItem(title: 'Profil Saya', icon: Icons.person_pin_rounded, route: '/profile'),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String get currentRoute => widget.currentRoute;
  Widget get child => widget.child;
  Timer? _backgroundSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LocalNotificationService().requestPermission();
      ref.read(notificationRepositoryProvider).syncSystemAlerts();
    });

    // Background sync timer every 15 minutes to keep operational alerts active
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      ref.read(notificationRepositoryProvider).syncSystemAlerts();
    });
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(currentUserProfileProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final notifRepo = ref.watch(notificationRepositoryProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isAdmin = userProfile?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final visibleNavItems = AppShell.navItems.where((item) => !item.adminOnly || isAdmin).toList();

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Desktop Sidebar
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: Border(right: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
              ),
              child: Column(
                children: [
                  // Brand Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? AppColors.cyan : const Color(0xFF0284C7)).withValues(alpha: 0.25),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(AppConstants.logoAsset, width: 34, height: 34, fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              AppConstants.companyName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Navigation Links
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      children: visibleNavItems.map((item) {
                        final isSelected = currentRoute == item.route ||
                            (item.route != '/' && currentRoute.startsWith(item.route));

                        final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryAccent.withValues(alpha: isDark ? 0.15 : 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: primaryAccent.withValues(alpha: 0.3))
                                : null,
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              item.icon,
                              color: isSelected
                                  ? primaryAccent
                                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                              size: 20,
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                color: isSelected
                                    ? (isDark ? Colors.white : primaryAccent)
                                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            trailing: item.route == '/notifications'
                                ? StreamBuilder<int>(
                                    stream: notifRepo.watchUnreadCount(),
                                    builder: (context, snap) {
                                      final count = snap.data ?? 0;
                                      if (count == 0) return const SizedBox.shrink();
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          count > 99 ? '99+' : '$count',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : null,
                            onTap: () => context.go(item.route),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Footer: User profile & quick controls
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => context.go('/profile'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: (isDark ? AppColors.cyan : const Color(0xFF0284C7)).withValues(alpha: 0.15),
                                        child: Text(
                                          (userProfile?.name.isNotEmpty ?? false)
                                              ? userProfile!.name[0].toUpperCase()
                                              : 'A',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userProfile?.name ?? 'Admin',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              userProfile?.isSuperAdmin == true ? 'SUPER ADMIN' : (userProfile?.role ?? 'staff').toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isAdmin
                                                    ? (isDark ? AppColors.cyan : const Color(0xFF0284C7))
                                                    : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Theme toggle button
                            IconButton(
                              icon: Icon(
                                themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                size: 18,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              ),
                              tooltip: 'Ganti Tema',
                              onPressed: () {
                                ref.read(themeModeProvider.notifier).toggle();
                              },
                            ),
                            // Logout button
                            IconButton(
                              icon: Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                              tooltip: 'Keluar',
                              onPressed: () => ConfirmationDialog.confirmAndSignOut(context, ref),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: child,
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================
    // MOBILE FIRST INTERFACE (< 900px)
    // ==========================================

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(AppConstants.logoAsset, width: 28, height: 28, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              AppConstants.appName,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.2),
            ),
            Text(
              AppConstants.companyName,
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
        actions: [
          // Notification Bell with dynamic unread badge
          StreamBuilder<int>(
            stream: notifRepo.watchUnreadCount(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 22),
                    tooltip: 'Notifikasi',
                    onPressed: () => context.go('/notifications'),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Theme Switcher
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            tooltip: 'Ubah Tema',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          // User Avatar
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              onTap: () => _showMobileMenu(context, ref, visibleNavItems, userProfile, isAdmin),
              borderRadius: BorderRadius.circular(16),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.cyan.withValues(alpha: 0.25),
                child: Text(
                  (userProfile?.name.isNotEmpty ?? false) ? userProfile!.name[0].toUpperCase() : 'A',
                  style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        height: 64,
        elevation: 8,
        selectedIndex: _getBottomNavIndex(currentRoute),
        onDestinationSelected: (idx) {
          switch (idx) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/customers');
              break;
            case 2:
              context.go('/services');
              break;
            case 3:
              context.go('/invoices');
              break;
            case 4:
              _showMobileMenu(context, ref, visibleNavItems, userProfile, isAdmin);
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.cyan),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_alt_rounded, color: AppColors.cyan),
            label: 'Pelanggan',
          ),
          NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns_rounded, color: AppColors.cyan),
            label: 'Layanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.cyan),
            label: 'Tagihan',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.cyan),
            label: 'Menu',
          ),
        ],
      ),
    );
  }

  int _getBottomNavIndex(String route) {
    if (route == '/') return 0;
    if (route.startsWith('/customers')) return 1;
    if (route.startsWith('/services')) return 2;
    if (route.startsWith('/invoices')) return 3;
    // Any secondary route is represented by the 4th tab (Menu)
    return 4;
  }

  void _showMobileMenu(
    BuildContext context,
    WidgetRef ref,
    List<NavItem> items,
    dynamic userProfile,
    bool isAdmin,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black54 : Colors.black12,
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle pill
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Profile Mini Card (Klik untuk membuka halaman profil)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      context.go('/profile');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.surfaceLightDark, AppColors.cyan.withValues(alpha: 0.08)]
                              : [const Color(0xFFF1F5F9), const Color(0xFFE0F2FE).withValues(alpha: 0.5)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.cyan.withValues(alpha: 0.2) : const Color(0xFFBAE6FD),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: (isDark ? AppColors.cyan : const Color(0xFF0284C7)).withValues(alpha: 0.15),
                            child: Text(
                              (userProfile?.name.isNotEmpty ?? false) ? userProfile!.name[0].toUpperCase() : 'A',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProfile?.name ?? 'Admin FuchurHost',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  userProfile?.email ?? 'admin@fuchurhost.com',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? (isDark ? AppColors.cyan.withValues(alpha: 0.2) : const Color(0xFFE0F2FE))
                                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              userProfile?.isSuperAdmin == true ? 'SUPER ADMIN' : (userProfile?.role ?? 'staff').toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isAdmin
                                    ? (isDark ? AppColors.cyan : const Color(0xFF0284C7))
                                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'OPERASIONAL & KEUANGAN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Grid of Primary Operational Items
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                    children: [
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.payments_rounded,
                        color: AppColors.success,
                        title: 'Pembayaran',
                        route: '/payments',
                        isDark: isDark,
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppColors.danger,
                        title: 'Kelola Pengeluaran',
                        route: '/expenses',
                        isDark: isDark,
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.analytics_rounded,
                        color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                        title: 'Keuangan',
                        route: '/finance',
                        isDark: isDark,
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.autorenew_rounded,
                        color: AppColors.warning,
                        title: 'Perpanjangan',
                        route: '/renewals',
                        isDark: isDark,
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.inventory_2_rounded,
                        color: isDark ? AppColors.electricBlue : const Color(0xFF0284C7),
                        title: 'Paket VPS',
                        route: '/packages',
                        isDark: isDark,
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.bar_chart_rounded,
                        color: const Color(0xFFA855F7),
                        title: 'Laporan',
                        route: '/reports',
                        isDark: isDark,
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.notifications_rounded,
                        color: AppColors.warning,
                        title: 'Notifikasi',
                        route: '/notifications',
                        isDark: isDark,
                        badgeCountStream: ref.read(notificationRepositoryProvider).watchUnreadCount(),
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.settings_rounded,
                        color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
                        title: 'Pengaturan',
                        route: '/settings',
                        isDark: isDark,
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.person_pin_rounded,
                        color: const Color(0xFF10B981),
                        title: 'Profil Saya',
                        route: '/profile',
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'SISTEM & PENGATURAN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Administrative / System items list
                  if (isAdmin) ...[
                    _buildListMenuItem(
                      ctx,
                      icon: Icons.manage_accounts_rounded,
                      title: 'Pengguna & Hak Akses',
                      subtitle: 'Kelola akun Super Admin, Administrator, dan staf',
                      route: '/users',
                      isDark: isDark,
                    ),
                    _buildListMenuItem(
                      ctx,
                      icon: Icons.history_edu_rounded,
                      title: 'Audit Log',
                      subtitle: 'Catatan aktivitas keamanan dan transaksi finansial',
                      route: '/audit',
                      isDark: isDark,
                    ),
                  ],
                  _buildListMenuItem(
                    ctx,
                    icon: Icons.person_pin_rounded,
                    title: 'Profil Saya',
                    subtitle: 'Lihat rincian data diri dan perbarui informasi profil',
                    route: '/profile',
                    isDark: isDark,
                  ),
                  _buildListMenuItem(
                    ctx,
                    icon: Icons.settings_rounded,
                    title: 'Pengaturan Sistem',
                    subtitle: 'Preferensi zona waktu, mata uang, dan backup',
                    route: '/settings',
                    isDark: isDark,
                  ),

                  const SizedBox(height: 14),
                  Divider(color: isDark ? AppColors.borderDark : AppColors.borderLight),

                  // Logout action
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                    ),
                    title: const Text('Keluar dari Akun', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      'Akhiri sesi operasional Fuchur Agent pada perangkat ini',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await ConfirmationDialog.confirmAndSignOut(context, ref);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuGridItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String route,
    required bool isDark,
    Stream<int>? badgeCountStream,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.borderLight),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (badgeCountStream != null)
              Positioned(
                top: 8,
                right: 8,
                child: StreamBuilder<int>(
                  stream: badgeCountStream,
                  builder: (context, snap) {
                    final count = snap.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isDark ? AppColors.cyan : const Color(0xFF0284C7), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
      ),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }
}
