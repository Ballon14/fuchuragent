import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../auth/models/user_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/app_pagination_bar.dart';

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  int _currentPage = 1;
  int _itemsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final currentUser = ref.watch(currentUserProfileProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    final isSuperAdminViewer = currentUser?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna & Hak Akses')),
      body: StreamBuilder<List<UserModel>>(
        stream: authRepo.watchAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Terjadi kesalahan memuat pengguna: ${snapshot.error}'),
              ),
            );
          }

          final users = snapshot.data ?? [];
          final totalItems = users.length;
          final totalPages = totalItems == 0 ? 1 : (totalItems / _itemsPerPage).ceil();
          final safeCurrentPage = _currentPage.clamp(1, totalPages);
          final startIndex = (safeCurrentPage - 1) * _itemsPerPage;
          final pageUsers = users.skip(startIndex).take(_itemsPerPage).toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.security_rounded, color: primaryColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manajemen Pengguna & Otoritas Sistem',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Super Admin memiliki otoritas tertinggi mutlak. Super Admin & Administrator dapat mengelola staf dan hak akses.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Current user banner
                if (currentUser != null) ...[
                  Row(
                    children: [
                      Icon(
                        currentUser.isSuperAdmin ? Icons.verified_user_rounded : Icons.admin_panel_settings_rounded,
                        size: 16,
                        color: currentUser.isSuperAdmin ? const Color(0xFF10B981) : primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Anda login sebagai: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        currentUser.isSuperAdmin
                            ? 'Super Admin (Pemilik Utama)'
                            : (currentUser.isAdmin ? 'Administrator' : 'Staf Teknis'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: currentUser.isSuperAdmin
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                              : primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Users list
                AppCard(
                  padding: EdgeInsets.zero,
                  child: users.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Belum ada pengguna lain terdaftar di Firestore.',
                              style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pageUsers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final u = pageUsers[idx];
                            final isRootSuperAdmin = u.email.toLowerCase().trim() == UserModel.superAdminEmail;
                            final isTargetSuperAdmin = u.isSuperAdmin;

                            // Avatar icon & color
                            Color avatarColor;
                            IconData avatarIcon;
                            if (isTargetSuperAdmin) {
                              avatarColor = const Color(0xFF10B981);
                              avatarIcon = Icons.stars_rounded;
                            } else if (u.isAdmin) {
                              avatarColor = primaryColor;
                              avatarIcon = Icons.shield_rounded;
                            } else {
                              avatarColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
                              avatarIcon = Icons.person_rounded;
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: CircleAvatar(
                                backgroundColor: avatarColor.withValues(alpha: 0.15),
                                child: Icon(avatarIcon, color: avatarColor, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    u.name.isNotEmpty ? u.name : 'Pengguna',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  if (u.id == currentUser?.id) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Anda',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  isRootSuperAdmin ? '${u.email} • Akun Root Pemilik' : u.email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              trailing: isRootSuperAdmin
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                                          SizedBox(width: 5),
                                          Text(
                                            'Super Admin (Root)',
                                            style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: u.role,
                                        dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                                        items: [
                                          if (isSuperAdminViewer)
                                            const DropdownMenuItem(
                                              value: 'superadmin',
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.stars_rounded, size: 14, color: Color(0xFF10B981)),
                                                  SizedBox(width: 6),
                                                  Text('Super Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          const DropdownMenuItem(
                                            value: 'admin',
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.shield_rounded, size: 14, color: Color(0xFF0284C7)),
                                                SizedBox(width: 6),
                                                Text('Administrator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                          const DropdownMenuItem(
                                            value: 'staff',
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.person_rounded, size: 14, color: Color(0xFF64748B)),
                                                SizedBox(width: 6),
                                                Text('Staf Teknis', style: TextStyle(fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ],
                                        onChanged: (newRole) async {
                                          if (newRole != null && newRole != u.role) {
                                            final confirmed = await ConfirmationDialog.show(
                                              context: context,
                                              title: 'Ubah Peran Pengguna',
                                              message:
                                                  'Apakah Anda yakin ingin mengubah peran "${u.name.isNotEmpty ? u.name : u.email}" menjadi "${newRole.toUpperCase()}"?',
                                              confirmText: 'Ya, Ubah Peran',
                                            );

                                            if (confirmed == true) {
                                              await authRepo.updateUserRole(
                                                u.id,
                                                newRole,
                                                targetName: u.name.isNotEmpty ? u.name : u.email,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Peran ${u.name} berhasil diubah menjadi ${newRole.toUpperCase()}.'),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ),
                            );
                          },
                        ),
                ),

                if (totalItems > _itemsPerPage) ...[
                  const SizedBox(height: 16),
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
}
