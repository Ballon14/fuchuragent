import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../auth/models/user_model.dart';
import '../../../shared/widgets/app_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _uidCtrl;

  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  bool _isSavingProfile = false;
  bool _isSavingPassword = false;
  bool _isSendingResetEmail = false;

  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _uidCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _uidCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _populateUserFields(UserModel user) {
    if (_nameCtrl.text.isEmpty && user.name.isNotEmpty) {
      _nameCtrl.text = user.name;
    }
    if (_phoneCtrl.text.isEmpty && user.phone.isNotEmpty) {
      _phoneCtrl.text = user.phone;
    }
    _emailCtrl.text = user.email;
    _uidCtrl.text = user.id;
  }

  Future<void> _handleSaveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      ref.invalidate(currentUserProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informasi profil data diri berhasil diperbarui.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui profil: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfirmasi kata sandi tidak cocok.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSavingPassword = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _currentPassCtrl.text,
            newPassword: _newPassCtrl.text,
          );
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kata sandi berhasil diubah.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah kata sandi: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  Future<void> _handleSendResetEmail(String email) async {
    if (email.isEmpty) return;

    setState(() => _isSendingResetEmail = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tautan reset kata sandi telah dikirimkan ke email: $email'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim email reset: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingResetEmail = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari sesi aplikasi Fuchur Agent?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar (Logout)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data Profil',
            onPressed: () => ref.invalidate(currentUserProfileProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: userAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: primaryAccent)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat profil: $err'),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Data profil tidak ditemukan.'));
          }

          _populateUserFields(user);

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Profile Banner
                _buildProfileBanner(context, user, isDesktop),
                SizedBox(height: isDesktop ? 24 : 16),

                // Main Content: 2-column on desktop, 1-column on mobile
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Personal Info Form (60%)
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildPersonalInfoCard(context, user),
                            const SizedBox(height: 24),
                            _buildAccessPermissionsCard(context, user),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Security, Password & Logout (40%)
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _buildSecurityCard(context, user),
                            const SizedBox(height: 24),
                            _buildAccountActionsCard(context),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  // Mobile Layout
                  _buildPersonalInfoCard(context, user),
                  const SizedBox(height: 16),
                  _buildSecurityCard(context, user),
                  const SizedBox(height: 16),
                  _buildAccessPermissionsCard(context, user),
                  const SizedBox(height: 16),
                  _buildAccountActionsCard(context),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileBanner(BuildContext context, UserModel user, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    Color roleColor;
    if (user.isSuperAdmin) {
      roleColor = const Color(0xFFEC4899); // Pink / SuperAdmin
    } else if (user.isAdmin) {
      roleColor = const Color(0xFF0284C7); // Blue / Admin
    } else {
      roleColor = const Color(0xFF10B981); // Emerald / Staff
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with glow & border
          Stack(
            children: [
              Container(
                width: isDesktop ? 76 : 60,
                height: isDesktop ? 76 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryAccent,
                      roleColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryAccent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: isDesktop ? 32 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(width: isDesktop ? 20 : 14),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name.isNotEmpty ? user.name : 'Pengguna FuchurHost',
                        style: TextStyle(
                          fontSize: isDesktop ? 20 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user.isSuperAdmin
                                ? Icons.shield_rounded
                                : (user.isAdmin ? Icons.admin_panel_settings_rounded : Icons.badge_rounded),
                            size: 13,
                            color: roleColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            user.roleLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: roleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                          SizedBox(width: 4),
                          Text(
                            'Akun Aktif',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    if (user.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Terdaftar: ${AppConstants.formatShortDate(user.createdAt)}',
                          style: TextStyle(
                            fontSize: 11,
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
    );
  }

  Widget _buildPersonalInfoCard(BuildContext context, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return AppCard(
      title: 'Informasi Data Diri & Kontak',
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perbarui nama lengkap dan nomor telepon/WhatsApp Anda untuk identitas operasional sistem.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),

            // Nama Lengkap (Editable)
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap / Tampilan *',
                hintText: 'Masukkan nama lengkap',
                prefixIcon: Icon(Icons.person_rounded, size: 18),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nama lengkap wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Nomor WhatsApp / Telepon (Editable)
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp / Kontak',
                hintText: '081234567890 / +6281234567890',
                prefixIcon: Icon(Icons.phone_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 16),

            // Alamat Email (Read-Only)
            TextFormField(
              controller: _emailCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Alamat Email Akun (Login)',
                prefixIcon: const Icon(Icons.email_rounded, size: 18),
                suffixIcon: Tooltip(
                  message: 'Email login diverifikasi oleh Firebase Auth',
                  child: Icon(Icons.lock_outline_rounded, size: 18, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                ),
                helperText: 'Email merupakan kredensial login utama dan bersifat permanen.',
              ),
            ),
            const SizedBox(height: 16),

            // UID Pengguna (Read-Only with Copy button)
            TextFormField(
              controller: _uidCtrl,
              readOnly: true,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'User ID (UID)',
                prefixIcon: const Icon(Icons.fingerprint_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Salin UID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _uidCtrl.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UID berhasil disalin ke clipboard.')),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Submit Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _isSavingProfile ? null : _handleSaveProfile,
                icon: _isSavingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _isSavingProfile ? 'Menyimpan...' : 'Simpan Perubahan Data Diri',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return AppCard(
      title: 'Keamanan Akun & Kata Sandi',
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastikan kata sandi Anda memiliki minimal 6 karakter dan sulit ditebak.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),

            // Kata Sandi Saat Ini
            TextFormField(
              controller: _currentPassCtrl,
              obscureText: _obscureCurrentPass,
              decoration: InputDecoration(
                labelText: 'Kata Sandi Saat Ini *',
                prefixIcon: const Icon(Icons.lock_clock_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrentPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscureCurrentPass = !_obscureCurrentPass),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Kata sandi saat ini wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Kata Sandi Baru
            TextFormField(
              controller: _newPassCtrl,
              obscureText: _obscureNewPass,
              decoration: InputDecoration(
                labelText: 'Kata Sandi Baru *',
                prefixIcon: const Icon(Icons.vpn_key_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                ),
              ),
              validator: (val) {
                if (val == null || val.length < 6) {
                  return 'Kata sandi baru minimal 6 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Konfirmasi Kata Sandi Baru
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirmPass,
              decoration: InputDecoration(
                labelText: 'Ulangi Kata Sandi Baru *',
                prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Konfirmasi kata sandi wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isSavingPassword ? null : _handleChangePassword,
                  icon: _isSavingPassword
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.security_rounded, size: 18),
                  label: Text(
                    _isSavingPassword ? 'Memperbarui...' : 'Perbarui Kata Sandi',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isSendingResetEmail ? null : () => _handleSendResetEmail(user.email),
                  icon: _isSendingResetEmail
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.forward_to_inbox_rounded, size: 16),
                  label: const Text('Kirim Tautan Reset ke Email'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessPermissionsCard(BuildContext context, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, dynamic>> permissions = [
      {
        'title': 'Manajemen Layanan VPS & Pelanggan',
        'desc': 'Tambah, edit, dan pantau status VPS serta kontak pelanggan.',
        'granted': true,
      },
      {
        'title': 'Kelola Tagihan & Pembayaran',
        'desc': 'Catat invoice baru, verifikasi pembayaran kas masuk, dan pelunasan.',
        'granted': true,
      },
      {
        'title': 'Pencatatan Pengeluaran Operasional',
        'desc': 'Rekap biaya server, lisensi, dan upah worker.',
        'granted': true,
      },
      {
        'title': 'Audit Log & Riwayat Aktivitas',
        'desc': 'Melihat rekam jejak setiap aksi krusial sistem.',
        'granted': user.isAdmin,
      },
      {
        'title': 'Pengelolaan Pengguna & Peran Akses',
        'desc': 'Mengatur hak akses dan penugasan peran Administrator/Staff.',
        'granted': user.isAdmin,
      },
    ];

    return AppCard(
      title: 'Hak Akses & Otoritas Sistem',
      child: Column(
        children: permissions.map((p) {
          final granted = p['granted'] as bool;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: granted ? AppColors.success.withValues(alpha: 0.15) : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    granted ? Icons.check_rounded : Icons.lock_outline_rounded,
                    size: 16,
                    color: granted ? AppColors.success : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: granted ? null : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p['desc'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAccountActionsCard(BuildContext context) {
    return AppCard(
      title: 'Sesi & Autentikasi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keluar dari sesi akun Anda pada perangkat ini dengan aman.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
            ),
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text(
              'Keluar dari Akun (Logout)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
