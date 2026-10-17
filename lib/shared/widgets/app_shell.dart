import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';

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

class AppShell extends ConsumerWidget {
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
    NavItem(title: 'Perpanjangan', icon: Icons.autorenew_rounded, route: '/renewals'),
    NavItem(title: 'Laporan', icon: Icons.bar_chart_rounded, route: '/reports'),
    NavItem(title: 'Notifikasi', icon: Icons.notifications_rounded, route: '/notifications'),
    NavItem(title: 'Pengguna', icon: Icons.manage_accounts_rounded, route: '/users', adminOnly: true),
    NavItem(title: 'Audit Log', icon: Icons.history_edu_rounded, route: '/audit', adminOnly: true),
    NavItem(title: 'Pengaturan', icon: Icons.settings_rounded, route: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(currentUserProfileProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isAdmin = userProfile?.isAdmin ?? false;

    final visibleNavItems = navItems.where((item) => !item.adminOnly || isAdmin).toList();

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Desktop Sidebar
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: const Border(right: BorderSide(color: AppColors.borderDark)),
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
                                color: AppColors.cyan.withValues(alpha: 0.25),
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
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              AppConstants.companyName,
                              style: TextStyle(fontSize: 11, color: Colors.white54),
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.cyan.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: AppColors.cyan.withValues(alpha: 0.3))
                                : null,
                          ),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              item.icon,
                              color: isSelected ? AppColors.cyan : Colors.white60,
                              size: 20,
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
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
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.cyan.withValues(alpha: 0.2),
                              child: Text(
                                (userProfile?.name.isNotEmpty ?? false)
                                    ? userProfile!.name[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.cyan),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userProfile?.name ?? 'Admin',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    userProfile?.isSuperAdmin == true ? 'SUPER ADMIN' : (userProfile?.role ?? 'staff').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isAdmin ? AppColors.cyan : Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Theme toggle button
                            IconButton(
                              icon: Icon(
                                themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                size: 18,
                              ),
                              onPressed: () {
                                ref.read(themeModeProvider.notifier).toggle();
                              },
                            ),
                            // Logout button
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white54),
                              onPressed: () async {
                                await ref.read(authRepositoryProvider).signOut();
                                if (context.mounted) context.go('/login');
                              },
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
    final notifRepo = ref.watch(notificationRepositoryProvider);

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 4),
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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Profile Mini Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.surfaceLightDark,
                          AppColors.cyan.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.cyan.withValues(alpha: 0.2),
                          child: Text(
                            (userProfile?.name.isNotEmpty ?? false) ? userProfile!.name[0].toUpperCase() : 'A',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.cyan, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userProfile?.name ?? 'Admin FuchurHost',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userProfile?.email ?? 'admin@fuchurhost.com',
                                style: const TextStyle(fontSize: 11, color: Colors.white60),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAdmin ? AppColors.cyan.withValues(alpha: 0.2) : Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            userProfile?.isSuperAdmin == true ? 'SUPER ADMIN' : (userProfile?.role ?? 'staff').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isAdmin ? AppColors.cyan : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'OPERASIONAL & KEUANGAN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
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
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.autorenew_rounded,
                        color: AppColors.warning,
                        title: 'Perpanjangan',
                        route: '/renewals',
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.inventory_2_rounded,
                        color: AppColors.electricBlue,
                        title: 'Paket VPS',
                        route: '/packages',
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.cloud_download_rounded,
                        color: AppColors.cyan,
                        title: 'Impor Sheets',
                        route: '/imports',
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.bar_chart_rounded,
                        color: const Color(0xFFA855F7),
                        title: 'Laporan',
                        route: '/reports',
                      ),
                      _buildMenuGridItem(
                        ctx,
                        icon: Icons.notifications_rounded,
                        color: AppColors.warning,
                        title: 'Notifikasi',
                        route: '/notifications',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'SISTEM & PENGATURAN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),

                  // Administrative / System items list
                  if (isAdmin) ...[
                    _buildListMenuItem(
                      ctx,
                      icon: Icons.manage_accounts_rounded,
                      title: 'Pengguna & Hak Akses',
                      subtitle: 'Kelola akun administrator dan staf FuchurHost',
                      route: '/users',
                    ),
                    _buildListMenuItem(
                      ctx,
                      icon: Icons.history_edu_rounded,
                      title: 'Audit Log',
                      subtitle: 'Catatan aktivitas keamanan dan transaksi finansial',
                      route: '/audit',
                    ),
                  ],
                  _buildListMenuItem(
                    ctx,
                    icon: Icons.settings_rounded,
                    title: 'Pengaturan Sistem',
                    subtitle: 'Preferensi zona waktu, mata uang, dan backup',
                    route: '/settings',
                  ),

                  const SizedBox(height: 14),
                  const Divider(),

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
                    subtitle: const Text('Akhiri sesi operasional Fuchur Agent pada perangkat ini', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/login');
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
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLightDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLightDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.cyan, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white38),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }
}
