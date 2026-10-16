import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Sistem')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Identity Card
            AppCard(
              title: 'Identitas Aplikasi & Bisnis',
              child: Column(
                children: [
                  _buildSettingRow('Nama Aplikasi', AppConstants.appName),
                  const Divider(height: 16),
                  _buildSettingRow('Entitas Bisnis', AppConstants.companyName),
                  const Divider(height: 16),
                  _buildSettingRow('Mata Uang Operasional', '${AppConstants.currencyCode} (Rupiah)'),
                  const Divider(height: 16),
                  _buildSettingRow('Zona Waktu Sistem', '${AppConstants.timezone} (WIB)'),
                  const Divider(height: 16),
                  _buildSettingRow('Versi Aplikasi', '1.0.0+1 (Production Ready)'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Infrastructure Card
            AppCard(
              title: 'Infrastruktur Backend & Firebase',
              child: Column(
                children: [
                  _buildSettingRow('Firebase Project ID', 'fuchuragent'),
                  const Divider(height: 16),
                  _buildSettingRow('Database Operasional', 'Cloud Firestore (Real-Time NoSQL)'),
                  const Divider(height: 16),
                  _buildSettingRow('Layanan Autentikasi', 'Firebase Authentication'),
                  const Divider(height: 16),
                  _buildSettingRow('Realtime Database', 'Tersambung (Asia Southeast 1)'),
                  const Divider(height: 16),
                  _buildSettingRow('Penyimpanan Media', 'Nonaktif (Free Tier — 0 Byte Storage)'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Theme Preferences
            AppCard(
              title: 'Tampilan & Tema',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gunakan Dark Mode (Tema Utama)'),
                subtitle: const Text('Warna charcoal/slate dengan aksen cyan elektrik'),
                value: themeMode == ThemeMode.dark,
                onChanged: (val) {
                  ref.read(themeModeProvider.notifier).setTheme(val ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ),

            const SizedBox(height: 24),

            // Catalog Maintenance
            AppCard(
              title: 'Katalog & Pemeliharaan Data',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inisialisasi ulang paket katalog referensi bawaan (Basic, Standard, Semi Pro, Pro, Snipe-it):',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sinkronkan Katalog Paket Standar'),
                    onPressed: () async {
                      await ref.read(packageRepositoryProvider).seedDefaultPackages();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Paket referensi berhasil disinkronkan ke Firestore.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
