import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/notification_model.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifRepo = ref.watch(notificationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi & Pemberitahuan Sistem'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Tandai Semua Dibaca'),
            onPressed: () async {
              await notifRepo.markAllAsRead();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua notifikasi ditandai telah dibaca.')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: notifRepo.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 56, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('Tidak ada notifikasi baru.', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final n = notifications[idx];
              Color iconColor;
              IconData iconData;

              switch (n.category) {
                case 'EXPIRATION':
                  iconColor = AppColors.warning;
                  iconData = Icons.timer_rounded;
                  break;
                case 'PAYMENT':
                  iconColor = AppColors.success;
                  iconData = Icons.payment_rounded;
                  break;
                case 'INVOICE':
                  iconColor = AppColors.electricBlue;
                  iconData = Icons.receipt_long_rounded;
                  break;
                default:
                  iconColor = AppColors.cyan;
                  iconData = Icons.info_outline_rounded;
              }

              return Card(
                color: n.isRead ? AppColors.surfaceDark : AppColors.surfaceLightDark,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withValues(alpha: 0.15),
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.cyan, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(n.message, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        AppConstants.formatDateTime(n.createdAt),
                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!n.isRead) {
                      notifRepo.markAsRead(n.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
