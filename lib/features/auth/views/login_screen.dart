import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (_isSignUp) {
        await authRepo.signUp(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
      } else {
        await authRepo.signIn(_emailCtrl.text, _passCtrl.text);
      }
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('[firebase_auth/', '').replaceAll(']', ':');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan email terlebih dahulu pada kolom input.')),
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tautan pemulihan password telah dikirim ke $email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pemulihan: $e')),
        );
      }
    }
  }

  Future<void> _showBootstrapDialog() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final passCtrl = TextEditingController(text: _passCtrl.text);
    final nameCtrl = TextEditingController(text: _nameCtrl.text.trim());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bootstrap Administrator'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Konfigurasikan akun sebagai Administrator utama sistem. Masukkan email & password akun yang telah didaftarkan.',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Akun'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password Akun'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap (Opsional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              final pass = passCtrl.text;
              final name = nameCtrl.text.trim();

              if (email.isEmpty || pass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email dan password wajib diisi.')),
                );
                return;
              }

              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              try {
                await ref.read(authRepositoryProvider).bootstrapAdmin(
                  name: name,
                  email: email,
                  password: pass,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hak akses administrator berhasil dikonfigurasi!')),
                  );
                  context.go('/');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal bootstrap: ${e.toString().replaceAll('Exception: ', '')}')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Jadikan Admin'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              elevation: isDark ? 0 : 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header & Brand
                      // Official Brand Logo
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              AppConstants.logoAsset,
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'VPS Management & Billing Operations',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Error Alert
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Name Field (if sign up)
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Nama wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email Field
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
                          if (!val.contains('@')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 6) return 'Password minimal 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Forgot Password Link
                      if (!_isSignUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _handleForgotPassword,
                            child: const Text('Lupa Password?', style: TextStyle(fontSize: 12, color: AppColors.cyan)),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Text(_isSignUp ? 'Daftar Akun Baru' : 'Masuk ke Sistem'),
                      ),
                      const SizedBox(height: 16),

                      // Toggle Switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignUp ? 'Sudah memiliki akun?' : 'Belum memiliki akun?',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = null;
                            }),
                            child: Text(
                              _isSignUp ? 'Masuk' : 'Daftar',
                              style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Admin Bootstrap Option
                      Center(
                        child: TextButton.icon(
                          icon: Icon(Icons.admin_panel_settings_outlined, size: 16, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                          label: Text(
                            'Alur Bootstrap Administrator',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                          ),
                          onPressed: _showBootstrapDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
