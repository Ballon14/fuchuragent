import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isTestingConnection = false;
  int? _latencyMs;
  String? _connectionError;

  Future<void> _testFirebaseConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionError = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      // Test read to Firestore
      await FirebaseFirestore.instance.collection('customers').limit(1).get();
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _latencyMs = stopwatch.elapsedMilliseconds;
          _isTestingConnection = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Koneksi Firebase & Firestore stabil: respons dalam $_latencyMs ms.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionError = e.toString();
          _isTestingConnection = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uji koneksi gagal: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Sistem')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Identity Card
            AppCard(
              title: 'Identitas Aplikasi & Bisnis',
              child: Column(
                children: [
                  _buildSettingRow(context, 'Nama Aplikasi', AppConstants.appName),
                  const Divider(height: 16),
                  _buildSettingRow(context, 'Entitas Bisnis', AppConstants.companyName),
                  const Divider(height: 16),
                  _buildSettingRow(context, 'Mata Uang Operasional', '${AppConstants.currencyCode} (Rupiah)'),
                  const Divider(height: 16),
                  _buildSettingRow(context, 'Zona Waktu Sistem', '${AppConstants.timezone} (WIB)'),
                  const Divider(height: 16),
                  _buildSettingRow(context, 'Versi Aplikasi', '1.0.0+1 (Production Ready)'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Infrastructure Backend & Firebase Card (Fixed Overflow Bug & Responsive Layout)
            AppCard(
              title: 'Infrastruktur Backend & Firebase',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Firebase Project ID with Copy action
                  _buildSettingRow(
                    context,
                    'Firebase Project ID',
                    'fuchuragent',
                    icon: Icons.cloud_outlined,
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'fuchuragent',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: primaryAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          tooltip: 'Salin Project ID',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: 'fuchuragent'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Firebase Project ID disalin ke clipboard.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),

                  // Database Operasional
                  _buildSettingRow(
                    context,
                    'Database Operasional',
                    'Cloud Firestore',
                    icon: Icons.storage_rounded,
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Cloud Firestore',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Online',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),

                  // Layanan Autentikasi
                  _buildSettingRow(
                    context,
                    'Layanan Autentikasi',
                    'Firebase Auth',
                    icon: Icons.lock_person_rounded,
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Firebase Auth',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Email/Password',
                            style: TextStyle(
                              color: primaryAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),

                  // Region Server Backend
                  _buildSettingRow(
                    context,
                    'Lokasi Server / Region',
                    'asia-southeast1 (Jakarta/SG)',
                    icon: Icons.language_rounded,
                  ),
                  const Divider(height: 16),

                  // Status Koneksi Terkini
                  _buildSettingRow(
                    context,
                    'Status Koneksi Real-Time',
                    _isTestingConnection
                        ? 'Memeriksa...'
                        : (_latencyMs != null
                            ? 'Stabil ($_latencyMs ms)'
                            : (_connectionError != null ? 'Gagal Terhubung' : 'Terhubung')),
                    icon: Icons.wifi_rounded,
                    valueColor: _connectionError != null
                        ? AppColors.danger
                        : (_latencyMs != null ? AppColors.success : null),
                  ),
                  const SizedBox(height: 16),

                  // Tombol Uji Koneksi Real-time
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                        ),
                      ),
                      onPressed: _isTestingConnection ? null : _testFirebaseConnection,
                      icon: _isTestingConnection
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded, size: 18),
                      label: Text(
                        _isTestingConnection
                            ? 'Memeriksa Latensi Firebase...'
                            : (_latencyMs != null ? 'Uji Ulang Koneksi Firebase' : 'Uji Koneksi Backend Firebase'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

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

            const SizedBox(height: 20),

            // Catalog Maintenance
            AppCard(
              title: 'Katalog & Pemeliharaan Data',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inisialisasi ulang paket katalog referensi bawaan (Basic, Standard, Semi Pro, Pro, Snipe-it):',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 14),
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

  /// Responsive row that guarantees zero overflow on narrow phone screens & desktop
  Widget _buildSettingRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Widget? trailingWidget,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isDark ? AppColors.cyan : const Color(0xFF0284C7),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (trailingWidget != null)
            Flexible(
              flex: 6,
              child: Align(
                alignment: Alignment.centerRight,
                child: trailingWidget,
              ),
            )
          else
            Expanded(
              flex: 6,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
