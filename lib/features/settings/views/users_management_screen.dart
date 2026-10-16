import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../auth/models/user_model.dart';
import '../../../shared/widgets/app_card.dart';

class UsersManagementScreen extends ConsumerWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna & Hak Akses')),
      body: FutureBuilder<List<UserModel>>(
        future: authRepo.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
          }

          final users = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daftar Administrator dan Staf Pengelola Sistem',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hanya Administrator yang memiliki wewenang untuk mengubah peran atau mengakses log audit.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 20),

                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final u = users[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: u.isAdmin ? AppColors.cyan.withValues(alpha: 0.2) : Colors.white10,
                          child: Text(
                            u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                            style: TextStyle(color: u.isAdmin ? AppColors.cyan : Colors.white70),
                          ),
                        ),
                        title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(u.email),
                        trailing: DropdownButton<String>(
                          value: u.role,
                          dropdownColor: AppColors.surfaceDark,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                            DropdownMenuItem(value: 'staff', child: Text('Staf Teknis')),
                          ],
                          onChanged: (newRole) async {
                            if (newRole != null && newRole != u.role) {
                              await authRepo.updateUserRole(u.id, newRole);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Peran ${u.name} diubah menjadi $newRole.')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
