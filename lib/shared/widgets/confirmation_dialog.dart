import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? detail;
  final IconData? icon;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.detail,
    this.icon,
    this.confirmText = 'Konfirmasi',
    this.cancelText = 'Batal',
    this.confirmColor = AppColors.cyan,
    this.isDestructive = false,
  });

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String? detail,
    IconData? icon,
    String confirmText = 'Konfirmasi',
    String cancelText = 'Batal',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        message: message,
        detail: detail,
        icon: icon,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: isDestructive ? AppColors.danger : AppColors.cyan,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  /// Specialized, standardized dialog for confirming user logout
  static Future<bool> showLogoutDialog(BuildContext context) {
    return show(
      context: context,
      title: 'Keluar dari Akun',
      icon: Icons.logout_rounded,
      message: 'Apakah Anda yakin ingin mengakhiri sesi dan keluar dari aplikasi Fuchur Agent?',
      detail: 'Anda harus memasukkan email dan kata sandi kembali untuk dapat mengakses sistem.',
      confirmText: 'Ya, Keluar Akun',
      cancelText: 'Batal',
      isDestructive: true,
    );
  }

  /// Specialized dialog for confirming creation of new data
  static Future<bool> showCreateConfirmation({
    required BuildContext context,
    required String title,
    required String itemName,
    String? detail,
  }) {
    return show(
      context: context,
      title: title,
      icon: Icons.add_circle_outline_rounded,
      message: 'Apakah Anda yakin ingin menyimpan dan menambahkan "$itemName" ke sistem?',
      detail: detail,
      confirmText: 'Ya, Tambahkan Data',
      cancelText: 'Batal',
      isDestructive: false,
    );
  }

  /// Specialized dialog for confirming updates or edits to existing data
  static Future<bool> showUpdateConfirmation({
    required BuildContext context,
    required String title,
    required String itemName,
    String? detail,
  }) {
    return show(
      context: context,
      title: title,
      icon: Icons.edit_note_rounded,
      message: 'Apakah Anda yakin ingin menyimpan perubahan pada "$itemName"?',
      detail: detail ?? 'Perubahan akan langsung diperbarui ke database.',
      confirmText: 'Ya, Simpan Perubahan',
      cancelText: 'Batal',
      isDestructive: false,
    );
  }

  /// Specialized dialog for confirming data deletion or archiving
  static Future<bool> showDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String itemName,
    String? detail,
    bool isArchive = false,
  }) {
    return show(
      context: context,
      title: title,
      icon: isArchive ? Icons.archive_outlined : Icons.delete_outline_rounded,
      message: isArchive
          ? 'Apakah Anda yakin ingin mengarsipkan "$itemName"?'
          : 'Apakah Anda yakin ingin menghapus "$itemName" secara permanen?',
      detail: detail ??
          (isArchive
              ? 'Data yang diarsipkan tidak akan tampil di daftar aktif.'
              : 'Tindakan ini permanen dan tidak dapat dibatalkan.'),
      confirmText: isArchive ? 'Ya, Arsipkan' : 'Ya, Hapus Data',
      cancelText: 'Batal',
      isDestructive: true,
    );
  }

  /// Convenience method that shows the logout confirmation, signs out via AuthRepository,
  /// redirects to /login, and displays a feedback SnackBar.
  static Future<bool> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showLogoutDialog(context);
    if (confirmed) {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Anda telah berhasil keluar dari akun Fuchur Agent.')),
              ],
            ),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultPrimary = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final effectiveColor = (confirmColor == AppColors.cyan) ? defaultPrimary : confirmColor;
    final effectiveFg = isDestructive
        ? Colors.white
        : (isDark ? Colors.black : Colors.white);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDestructive ? AppColors.danger : effectiveColor).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDestructive ? AppColors.danger : effectiveColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.4,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D2A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      detail!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(cancelText),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveColor,
            foregroundColor: effectiveFg,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 1,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
