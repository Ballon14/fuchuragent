import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/system_settings_model.dart';
import '../repositories/settings_repository.dart';
import '../../notifications/services/local_notification_service.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Active editable settings state
  SystemSettingsModel? _settings;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // Controllers for Business & Profile
  final _companyNameCtrl = TextEditingController();
  final _brandNameCtrl = TextEditingController();
  final _supportEmailCtrl = TextEditingController();
  final _supportPhoneCtrl = TextEditingController();
  final _officeAddressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // Controllers for WhatsApp
  final _waGreetingCtrl = TextEditingController();
  final _waClosingCtrl = TextEditingController();
  final _waSignatureCtrl = TextEditingController();

  // Infrastructure & Diagnostics
  bool _isTestingConnection = false;
  int? _latencyMs;
  String? _connectionError;
  bool _isSeedingCatalog = false;

  // Database stats
  DatabaseStats? _dbStats;
  bool _isLoadingStats = false;

  // Notifications permission state
  bool _notificationsPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSettings();
    _checkNotificationPermission();
    _loadDatabaseStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameCtrl.dispose();
    _brandNameCtrl.dispose();
    _supportEmailCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _officeAddressCtrl.dispose();
    _websiteCtrl.dispose();
    _waGreetingCtrl.dispose();
    _waClosingCtrl.dispose();
    _waSignatureCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final current = await repo.getSettings();
      _applySettingsToForm(current);
    } catch (_) {
      final def = SystemSettingsModel.defaultSettings();
      _applySettingsToForm(def);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applySettingsToForm(SystemSettingsModel settings) {
    _settings = settings;
    _companyNameCtrl.text = settings.companyName;
    _brandNameCtrl.text = settings.brandName;
    _supportEmailCtrl.text = settings.supportEmail;
    _supportPhoneCtrl.text = settings.supportPhone;
    _officeAddressCtrl.text = settings.officeAddress;
    _websiteCtrl.text = settings.website;
    _waGreetingCtrl.text = settings.waGreeting;
    _waClosingCtrl.text = settings.waClosing;
    _waSignatureCtrl.text = settings.waAdminSignature;
    _hasUnsavedChanges = false;
  }

  Future<void> _checkNotificationPermission() async {
    try {
      final granted = await LocalNotificationService().areNotificationsEnabled();
      if (mounted) {
        setState(() => _notificationsPermissionGranted = granted);
      }
    } catch (_) {}
  }

  Future<void> _loadDatabaseStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final stats = await repo.getDatabaseStats();
      if (mounted) {
        setState(() {
          _dbStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Simpan Pengaturan Sistem',
      message: 'Apakah Anda yakin ingin menyimpan seluruh konfigurasi sistem ke database?',
      confirmText: 'Ya, Simpan Pengaturan',
      cancelText: 'Batal',
      icon: Icons.save_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final updated = _settings!.copyWith(
        companyName: _companyNameCtrl.text.trim(),
        brandName: _brandNameCtrl.text.trim(),
        supportEmail: _supportEmailCtrl.text.trim(),
        supportPhone: _supportPhoneCtrl.text.trim(),
        officeAddress: _officeAddressCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        waGreeting: _waGreetingCtrl.text.trim(),
        waClosing: _waClosingCtrl.text.trim(),
        waAdminSignature: _waSignatureCtrl.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      final updatedBy = user?.displayName ?? user?.email ?? 'Admin';

      await ref.read(settingsRepositoryProvider).saveSettings(updated, updatedBy: updatedBy);

      if (mounted) {
        setState(() {
          _settings = updated;
          _hasUnsavedChanges = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Pengaturan sistem berhasil disimpan secara permanen.')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengaturan: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _confirmResetDefaults() async {
    final confirm = await ConfirmationDialog.show(
      context: context,
      title: 'Reset Pengaturan Bawaan',
      message: 'Seluruh konfigurasi sistem (profil bisnis, rekening bank, template WhatsApp, dan aturan notifikasi) akan dikembalikan ke nilai default standar. Lanjutkan?',
      confirmText: 'Ya, Reset Default',
      cancelText: 'Batal',
      isDestructive: true,
      icon: Icons.restore_rounded,
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        await ref
            .read(settingsRepositoryProvider)
            .resetToDefaults(updatedBy: user?.displayName ?? user?.email);
        final def = await ref.read(settingsRepositoryProvider).getSettings();
        if (mounted) {
          _applySettingsToForm(def);
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengaturan berhasil direset ke nilai awal bawaan.'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mereset: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _testFirebaseConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionError = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
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

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengaturan Sistem')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentSettings = _settings ?? SystemSettingsModel.defaultSettings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Sistem'),
        actions: [
          if (_hasUnsavedChanges)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded, size: 14, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text(
                    'Belum Disimpan',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            tooltip: 'Muat Ulang Pengaturan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSettings,
          ),
          IconButton(
            tooltip: 'Reset ke Bawaan Sistem',
            icon: const Icon(Icons.restore_rounded),
            onPressed: _confirmResetDefaults,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: primaryAccent,
          labelColor: primaryAccent,
          unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
          tabs: const [
            Tab(icon: Icon(Icons.business_rounded, size: 18), text: 'Profil & Bisnis'),
            Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'Metode Pembayaran'),
            Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 18), text: 'Template WhatsApp'),
            Tab(icon: Icon(Icons.notifications_active_outlined, size: 18), text: 'Notifikasi & Otomasi'),
            Tab(icon: Icon(Icons.palette_outlined, size: 18), text: 'Tampilan & Regional'),
            Tab(icon: Icon(Icons.cloud_sync_outlined, size: 18), text: 'Database & Diagnostik'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBusinessProfileTab(currentSettings, isDark, primaryAccent),
          _buildPaymentMethodsTab(currentSettings, isDark, primaryAccent),
          _buildWhatsAppTab(currentSettings, isDark, primaryAccent),
          _buildNotificationsTab(currentSettings, isDark, primaryAccent),
          _buildAppearanceTab(currentSettings, isDark, primaryAccent),
          _buildDatabaseDiagnosticsTab(currentSettings, isDark, primaryAccent, isDesktop),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _confirmResetDefaults,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text('Reset Bawaan'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan Semua Pengaturan',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: PROFIL & BISNIS
  // ===========================================================================
  Widget _buildBusinessProfileTab(
    SystemSettingsModel settings,
    bool isDark,
    Color primaryAccent,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            title: 'Identitas Bisnis & Perusahaan',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informasi identitas ini otomatis disematkan pada faktur invoice, template penagihan WhatsApp, dan header dokumen resmi.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Perusahaan / Legal Entity',
                    hintText: 'Contoh: PT Solusi Cloud Indonesia',
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                  onChanged: (_) => _markChanged(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _brandNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Brand / Aplikasi',
                    hintText: 'Contoh: Fuchur Agent',
                    prefixIcon: Icon(Icons.verified_rounded),
                  ),
                  onChanged: (_) => _markChanged(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _supportEmailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email Layanan Pelanggan (CS)',
                    hintText: 'support@fuchuragent.id',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => _markChanged(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _supportPhoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp Helpdesk / Admin',
                    hintText: '081234567890',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => _markChanged(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _websiteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Website Resmi',
                    hintText: 'https://fuchuragent.id',
                    prefixIcon: Icon(Icons.language_rounded),
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => _markChanged(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _officeAddressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Kantor Operasional',
                    hintText: 'Gedung Cyber, Lt. 8, Jl. H. R. Rasuna Said, Jakarta',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  maxLines: 2,
                  onChanged: (_) => _markChanged(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ===========================================================================
  // TAB 2: METODE PEMBAYARAN & REKENING DINAMIS
  // ===========================================================================
  Widget _buildPaymentMethodsTab(
    SystemSettingsModel settings,
    bool isDark,
    Color primaryAccent,
  ) {
    final methods = settings.paymentMethods;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            title: 'Metode Pembayaran & Rekening Dinamis',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Kelola rekening bank dan channel pembayaran secara dinamis. Anda dapat menambah atau mengubah nomor rekening, atas nama, catatan, atau menonaktifkan rekening kapan saja tanpa mengubah nominal transaksi.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_card_rounded, size: 16),
                      label: const Text('Tambah Metode Pembayaran'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showAddEditPaymentMethodDialog(null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (methods.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 48, color: isDark ? Colors.white38 : Colors.grey),
                        const SizedBox(height: 8),
                        const Text('Belum ada metode pembayaran yang terdaftar.'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Tambah Metode Pembayaran Pertama'),
                          onPressed: () => _showAddEditPaymentMethodDialog(null),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: methods.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final item = methods[index];
                      final iconData = item.type == 'qris'
                          ? Icons.qr_code_2_rounded
                          : (item.type == 'ewallet'
                              ? Icons.account_balance_wallet_rounded
                              : (item.type == 'cash'
                                  ? Icons.payments_rounded
                                  : (item.type == 'credit_card'
                                      ? Icons.credit_card_rounded
                                      : Icons.account_balance_rounded)));

                      final typeLabel = item.type == 'qris'
                          ? 'QRIS'
                          : (item.type == 'ewallet'
                              ? 'E-Wallet'
                              : (item.type == 'cash'
                                  ? 'Kas Tunai'
                                  : (item.type == 'credit_card'
                                      ? 'Kartu Kredit'
                                      : 'Transfer Bank')));

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? (item.isDefault
                                  ? primaryAccent.withValues(alpha: 0.1)
                                  : AppColors.surfaceLightDark)
                              : (item.isDefault
                                  ? const Color(0xFFE0F2FE)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: item.isDefault
                                ? primaryAccent.withValues(alpha: 0.6)
                                : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                            width: item.isDefault ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: primaryAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(iconData, color: primaryAccent, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isDark ? Colors.white12 : Colors.black12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              typeLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                          if (item.isDefault) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'UTAMA',
                                                style: TextStyle(
                                                  color: AppColors.success,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (!item.isActive) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.danger.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'NONAKTIF',
                                                style: TextStyle(
                                                  color: AppColors.danger,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Text(
                                            'No. Rekening / ID: ',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          SelectableText(
                                            item.accountNumber.isNotEmpty ? item.accountNumber : '-',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (item.accountNumber.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () {
                                                Clipboard.setData(ClipboardData(text: item.accountNumber));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Nomor rekening ${item.name} (${item.accountNumber}) disalin ke clipboard.'),
                                                  ),
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.all(2.0),
                                                child: Icon(Icons.copy_rounded, size: 14),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (item.accountHolder.isNotEmpty)
                                        Text(
                                          'Atas Nama: ${item.accountHolder}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                          ),
                                        ),
                                      if (item.notes.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Catatan: ${item.notes}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: item.isActive ? 'Nonaktifkan Rekening' : 'Aktifkan Rekening',
                                      child: Switch(
                                        value: item.isActive,
                                        activeThumbColor: AppColors.success,
                                        onChanged: (val) => _togglePaymentMethodActive(item.id, val),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                                      tooltip: 'Ubah Nomor Rekening & Data',
                                      onPressed: () => _showAddEditPaymentMethodDialog(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          size: 18, color: AppColors.danger),
                                      tooltip: 'Hapus Metode Pembayaran',
                                      onPressed: () => _deletePaymentMethod(item.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditPaymentMethodDialog(PaymentMethodModel? existing) {
    String selectedType = existing?.type ?? 'bank_transfer';
    final nameCtrl = TextEditingController(text: existing?.name ?? 'Bank BCA');
    final numCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final holderCtrl = TextEditingController(text: existing?.accountHolder ?? 'Fuchur Agent');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    bool isDefault = existing?.isDefault ?? false;
    bool isActive = existing?.isActive ?? true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  existing == null ? Icons.add_card_rounded : Icons.edit_note_rounded,
                  color: AppColors.cyan,
                ),
                const SizedBox(width: 8),
                Text(existing == null ? 'Tambah Metode Pembayaran' : 'Ubah Rekening & Metode'),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nomor rekening dan identitas pembayaran dapat dirubah-rubah secara dinamis.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Tipe Saluran Pembayaran',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'bank_transfer', child: Text('Transfer Bank')),
                        DropdownMenuItem(value: 'qris', child: Text('QRIS Statis / Dinamis')),
                        DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet Dompet Digital')),
                        DropdownMenuItem(value: 'credit_card', child: Text('Kartu Kredit / Debit')),
                        DropdownMenuItem(value: 'cash', child: Text('Tunai / Kas Langsung')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: [
                        'Bank BCA',
                        'Bank Mandiri',
                        'Bank BRI',
                        'Bank BNI',
                        'Bank Syariah (BSI)',
                        'Bank Jago',
                        'BCA Syariah',
                        'Seabank',
                        'Bank Permata',
                        'Bank Danamon',
                        'Bank CIMB Niaga',
                        'QRIS Semua Pembayaran',
                        'GoPay',
                        'OVO',
                        'Dana',
                        'ShopeePay',
                        'Kas Tunai',
                      ].contains(nameCtrl.text)
                          ? nameCtrl.text
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Bank / Saluran Populer',
                        prefixIcon: Icon(Icons.account_balance_rounded),
                      ),
                      hint: const Text('Pilih atau ketik di bawah'),
                      items: const [
                        DropdownMenuItem(value: 'Bank BCA', child: Text('Bank BCA')),
                        DropdownMenuItem(value: 'Bank Mandiri', child: Text('Bank Mandiri')),
                        DropdownMenuItem(value: 'Bank BRI', child: Text('Bank BRI')),
                        DropdownMenuItem(value: 'Bank BNI', child: Text('Bank BNI')),
                        DropdownMenuItem(value: 'Bank Syariah (BSI)', child: Text('Bank Syariah (BSI)')),
                        DropdownMenuItem(value: 'Bank Jago', child: Text('Bank Jago')),
                        DropdownMenuItem(value: 'BCA Syariah', child: Text('BCA Syariah')),
                        DropdownMenuItem(value: 'Seabank', child: Text('Seabank')),
                        DropdownMenuItem(value: 'Bank Permata', child: Text('Bank Permata')),
                        DropdownMenuItem(value: 'Bank Danamon', child: Text('Bank Danamon')),
                        DropdownMenuItem(value: 'Bank CIMB Niaga', child: Text('Bank CIMB Niaga')),
                        DropdownMenuItem(value: 'QRIS Semua Pembayaran', child: Text('QRIS Semua Pembayaran')),
                        DropdownMenuItem(value: 'GoPay', child: Text('GoPay')),
                        DropdownMenuItem(value: 'OVO', child: Text('OVO')),
                        DropdownMenuItem(value: 'Dana', child: Text('Dana')),
                        DropdownMenuItem(value: 'ShopeePay', child: Text('ShopeePay')),
                        DropdownMenuItem(value: 'Kas Tunai', child: Text('Kas Tunai')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => nameCtrl.text = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Metode / Bank *',
                        hintText: 'Contoh: Bank BCA / QRIS',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: numCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Rekening / No. HP / Merchant ID *',
                        hintText: 'Contoh: 1234567890 (Dapat dirubah sewaktu-waktu)',
                        prefixIcon: Icon(Icons.numbers_rounded),
                        helperText: 'Rekening ini dinamis dan dapat diubah tanpa mempengaruhi nominal.',
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: holderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Atas Nama Pemilik Rekening *',
                        hintText: 'Contoh: Fuchur Agent',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Petunjuk Transfer / Catatan (Opsional)',
                        hintText: 'Contoh: Cantumkan ID Invoice di berita transfer',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Status Aktif'),
                      subtitle: const Text('Tampilkan metode ini pada form penagihan invoice & WhatsApp'),
                      value: isActive,
                      onChanged: (val) => setDlgState(() => isActive = val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Jadikan Metode Pembayaran Utama (Default)'),
                      value: isDefault,
                      onChanged: (val) => setDlgState(() => isDefault = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;

                  final isEdit = existing != null;
                  final confirmed = isEdit
                      ? await ConfirmationDialog.showUpdateConfirmation(
                          context: ctx,
                          title: 'Perbarui Metode Pembayaran',
                          itemName: nameCtrl.text.trim(),
                          detail: '${numCtrl.text.trim()} a.n ${holderCtrl.text.trim()}',
                        )
                      : await ConfirmationDialog.showCreateConfirmation(
                          context: ctx,
                          title: 'Tambah Metode Pembayaran',
                          itemName: nameCtrl.text.trim(),
                          detail: '${numCtrl.text.trim()} a.n ${holderCtrl.text.trim()}',
                        );

                  if (!confirmed || !ctx.mounted) return;

                  final currentMethods = List<PaymentMethodModel>.from(_settings!.paymentMethods);
                  final methodId = existing?.id ?? 'pm-${DateTime.now().millisecondsSinceEpoch}';

                  if (isDefault) {
                    for (int i = 0; i < currentMethods.length; i++) {
                      currentMethods[i] = currentMethods[i].copyWith(isDefault: false);
                    }
                  }

                  final newMethod = PaymentMethodModel(
                    id: methodId,
                    name: nameCtrl.text.trim(),
                    accountNumber: numCtrl.text.trim(),
                    accountHolder: holderCtrl.text.trim(),
                    type: selectedType,
                    notes: notesCtrl.text.trim(),
                    isActive: isActive,
                    isDefault: isDefault,
                  );

                  final idx = currentMethods.indexWhere((m) => m.id == methodId);
                  if (idx >= 0) {
                    currentMethods[idx] = newMethod;
                  } else {
                    currentMethods.add(newMethod);
                  }

                  final updated = _settings!.copyWith(
                    paymentMethods: currentMethods,
                    bankAccounts: currentMethods.map((m) => m.toBankAccount()).toList(),
                  );

                  setState(() {
                    _settings = updated;
                    _hasUnsavedChanges = false;
                  });

                  Navigator.pop(ctx);

                  final messenger = ScaffoldMessenger.of(context);

                  // Persist directly to Firestore database
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    final updatedBy = user?.displayName ?? user?.email ?? 'Admin';
                    await ref.read(settingsRepositoryProvider).saveSettings(updated, updatedBy: updatedBy);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(isEdit
                            ? 'Metode pembayaran "${newMethod.name}" berhasil diperbarui dan tersimpan permanen.'
                            : 'Metode pembayaran "${newMethod.name}" berhasil ditambahkan dan tersimpan permanen.'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Gagal menyimpan metode pembayaran: $e'),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }

                },
                child: const Text('Simpan Metode Pembayaran'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _togglePaymentMethodActive(String id, bool isActive) async {
    final currentMethods = List<PaymentMethodModel>.from(_settings!.paymentMethods);
    final idx = currentMethods.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      currentMethods[idx] = currentMethods[idx].copyWith(isActive: isActive);
      final updated = _settings!.copyWith(
        paymentMethods: currentMethods,
        bankAccounts: currentMethods.map((m) => m.toBankAccount()).toList(),
      );
      setState(() {
        _settings = updated;
      });
      try {
        final user = FirebaseAuth.instance.currentUser;
        final updatedBy = user?.displayName ?? user?.email ?? 'Admin';
        await ref.read(settingsRepositoryProvider).saveSettings(updated, updatedBy: updatedBy);
      } catch (_) {}
    }
  }

  Future<void> _deletePaymentMethod(String id) async {
    final target = _settings?.paymentMethods.firstWhere(
      (m) => m.id == id,
      orElse: () => const PaymentMethodModel(
        id: '',
        name: 'Metode Pembayaran',
        accountNumber: '',
        accountHolder: '',
        type: 'bank',
      ),
    );

    final confirmed = await ConfirmationDialog.showDeleteConfirmation(
      context: context,
      title: 'Hapus Metode Pembayaran',
      itemName: target?.name.isNotEmpty == true ? target!.name : 'Metode Pembayaran',
      detail: target != null && target.accountNumber.isNotEmpty
          ? '${target.accountNumber} a.n ${target.accountHolder}'
          : null,
    );
    if (!confirmed || !mounted) return;

    final currentMethods = List<PaymentMethodModel>.from(_settings!.paymentMethods);
    currentMethods.removeWhere((m) => m.id == id);
    final updated = _settings!.copyWith(
      paymentMethods: currentMethods,
      bankAccounts: currentMethods.map((m) => m.toBankAccount()).toList(),
    );
    setState(() {
      _settings = updated;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final updatedBy = user?.displayName ?? user?.email ?? 'Admin';
      await ref.read(settingsRepositoryProvider).saveSettings(updated, updatedBy: updatedBy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metode pembayaran berhasil dihapus dari database.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  // ===========================================================================
  // TAB 3: TEMPLATE WHATSAPP
  // ===========================================================================
  Widget _buildWhatsAppTab(
    SystemSettingsModel settings,
    bool isDark,
    Color primaryAccent,
  ) {
    // Generate live preview text
    final previewText = '''${_waGreetingCtrl.text.replaceAll('{name}', 'Budi Santoso')}

Kami dari *${_brandNameCtrl.text.isNotEmpty ? _brandNameCtrl.text : 'Fuchur Agent'}* ingin menginformasikan bahwa masa aktif layanan VPS Anda akan segera berakhir:

🌐 *Detail Layanan VPS:*
• Domain / Host: *example-vps.com*
• Paket: *Standard Cloud* (2 vCPU, 4GB RAM, 80GB Disk)
• Tanggal Jatuh Tempo: *25 Oktober 2026* (7 hari lagi)
• Biaya Perpanjangan: *Rp 135.000* / bulan

Untuk menjaga agar server tetap online tanpa interupsi, silakan lakukan konfirmasi perpanjangan sewa.

💳 *Rekening Pembayaran Resmi:*
${settings.bankAccounts.map((b) => '• ${b.bankName}: *${b.accountNumber}* a.n *${b.accountHolder}*').join('\n')}

${_waClosingCtrl.text}

*${_waSignatureCtrl.text}*''';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            title: 'Kustomisasi Template Pengingat WhatsApp',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Format teks otomatis yang dikirim ke pelanggan saat masa sewa VPS hampir berakhir atau sudah kedaluwarsa.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _waGreetingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Format Salam Pembuka',
                    hintText: 'Halo Kak *{name}*,',
                    helperText: 'Gunakan tag {name} untuk menyisipkan nama pelanggan secara otomatis.',
                    prefixIcon: Icon(Icons.waving_hand_rounded),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _markChanged();
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _waClosingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kalimat Penutup / Call to Action',
                    hintText: 'Terima kasih atas kepercayaan Kakak menggunakan layanan kami!',
                    prefixIcon: Icon(Icons.favorite_outline_rounded),
                  ),
                  maxLines: 2,
                  onChanged: (_) {
                    setState(() {});
                    _markChanged();
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _waSignatureCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tanda Tangan Pengirim (Signature)',
                    hintText: 'Fuchur Agent Team',
                    prefixIcon: Icon(Icons.fingerprint_rounded),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _markChanged();
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sertakan Rincian Rekening Bank Otomatis'),
                  subtitle: const Text('Menyisipkan nomor rekening resmi pada setiap template pesan tagihan'),
                  value: settings.includeBankDetailsInWa,
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings!.copyWith(includeBankDetailsInWa: val);
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Live Interactive Preview Box
          AppCard(
            title: 'Pratinjau Pesan WhatsApp (Live Preview)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 14, color: Color(0xFF25D366)),
                          SizedBox(width: 4),
                          Text(
                            'WhatsApp Message Simulator',
                            style: TextStyle(
                              color: Color(0xFF25D366),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Salin Contoh Teks',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: previewText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Teks pratinjau disalin.')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0C131D) : const Color(0xFFDCF8C6).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFBBE5B3),
                    ),
                  ),
                  child: SelectableText(
                    previewText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.45,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: NOTIFIKASI & OTOMASI
  // ===========================================================================
  Widget _buildNotificationsTab(
    SystemSettingsModel settings,
    bool isDark,
    Color primaryAccent,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            title: 'Aturan & Jadwal Pengingat Otomatis',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktifkan Notifikasi Jatuh Tempo VPS'),
                  subtitle: const Text('Kirim peringatan ke perangkat ketika ada server yang mendekati kedaluwarsa'),
                  value: settings.enableDueReminders,
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings!.copyWith(enableDueReminders: val);
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
                const Divider(height: 20),
                const Text(
                  'Kirim Notifikasi Pada Hari (Reminder Milestones):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [7, 5, 3, 1, 0].map((days) {
                    final isSelected = settings.reminderDays.contains(days);
                    final label = days == 0 ? 'Hari H (Jatuh Tempo)' : 'H-$days ($days Hari Sebelum)';
                    return FilterChip(
                      selected: isSelected,
                      label: Text(label),
                      selectedColor: primaryAccent.withValues(alpha: 0.2),
                      checkmarkColor: primaryAccent,
                      onSelected: (selected) {
                        final currentDays = List<int>.from(settings.reminderDays);
                        if (selected) {
                          if (!currentDays.contains(days)) currentDays.add(days);
                        } else {
                          currentDays.remove(days);
                        }
                        currentDays.sort((a, b) => b.compareTo(a));
                        setState(() {
                          _settings = _settings!.copyWith(reminderDays: currentDays);
                          _hasUnsavedChanges = true;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: settings.reminderHour,
                  decoration: const InputDecoration(
                    labelText: 'Waktu Pengiriman Notifikasi Harian',
                    prefixIcon: Icon(Icons.schedule_rounded),
                    helperText: 'Pukul berapa sistem akan mengecek dan memunculkan notifikasi pengingat',
                  ),
                  items: const [
                    DropdownMenuItem(value: 8, child: Text('08:00 WIB (Pagi Hari)')),
                    DropdownMenuItem(value: 9, child: Text('09:00 WIB (Jam Kerja Pagi - Rekomendasi)')),
                    DropdownMenuItem(value: 10, child: Text('10:00 WIB (Siang Menjelang Siang)')),
                    DropdownMenuItem(value: 13, child: Text('13:00 WIB (Setelah Istirahat Siang)')),
                    DropdownMenuItem(value: 17, child: Text('17:00 WIB (Sore Hari)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings!.copyWith(reminderHour: val);
                        _hasUnsavedChanges = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Feedback & Preferences
          AppCard(
            title: 'Preferensi Audio & Notifikasi Tambahan',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Suara Notifikasi Sistem'),
                  value: settings.soundEnabled,
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings!.copyWith(soundEnabled: val);
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
                const Divider(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Getaran Notifikasi (Vibration)'),
                  value: settings.vibrationEnabled,
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings!.copyWith(vibrationEnabled: val);
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
                const Divider(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifikasi Saat Ada Pengeluaran Baru'),
                  value: settings.notifyNewExpenses,
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings!.copyWith(notifyNewExpenses: val);
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
                const Divider(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifikasi Saat Ada Tagihan Invoice Baru'),
                  value: settings.notifyNewInvoices,
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings!.copyWith(notifyNewInvoices: val);
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // OS Permission & Diagnostics
          AppCard(
            title: 'Diagnostik Izin Notifikasi Perangkat',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _notificationsPermissionGranted
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: _notificationsPermissionGranted
                          ? AppColors.success
                          : AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _notificationsPermissionGranted
                          ? 'Izin Notifikasi Sistem: Aktif & Diizinkan'
                          : 'Izin Notifikasi Sistem: Belum Diizinkan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _notificationsPermissionGranted
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.security_update_good_rounded, size: 16),
                        label: const Text('Minta Izin Notifikasi OS'),
                        onPressed: () async {
                          final granted = await LocalNotificationService().requestPermission();
                          setState(() => _notificationsPermissionGranted = granted);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(granted
                                    ? 'Izin notifikasi sistem berhasil diberikan!'
                                    : 'Izin notifikasi belum diizinkan oleh sistem operasi.'),
                                backgroundColor: granted ? AppColors.success : AppColors.warning,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Kirim Tes Notifikasi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await LocalNotificationService().showTestNotification();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notifikasi uji coba dikirim ke bilah status/toast.'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
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

  // ===========================================================================
  // TAB 5: TAMPILAN & REGIONAL
  // ===========================================================================
  Widget _buildAppearanceTab(
    SystemSettingsModel settings,
    bool isDark,
    Color primaryAccent,
  ) {
    final themeMode = ref.watch(themeModeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            title: 'Tema & Visual Antarmuka',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gunakan Dark Mode (Tema Utama)'),
                  subtitle: const Text('Pilihan tema disimpan otomatis secara permanen di perangkat ini'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).setTheme(val ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
                const Divider(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: settings.defaultItemsPerPage,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah Baris Default Per Halaman Tabel',
                    prefixIcon: Icon(Icons.table_rows_rounded),
                    helperText: 'Menentukan berapa baris data VPS/Pelanggan yang dimuat di setiap halaman',
                  ),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10 Baris per Halaman (Standar)')),
                    DropdownMenuItem(value: 25, child: Text('25 Baris per Halaman')),
                    DropdownMenuItem(value: 50, child: Text('50 Baris per Halaman')),
                    DropdownMenuItem(value: 100, child: Text('100 Baris per Halaman (Desktop Luas)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings!.copyWith(defaultItemsPerPage: val);
                        _hasUnsavedChanges = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Regional & Formatting
          AppCard(
            title: 'Format Regional & Mata Uang',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: settings.currencyCode,
                  decoration: const InputDecoration(
                    labelText: 'Mata Uang Operasional',
                    prefixIcon: Icon(Icons.monetization_on_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'IDR', child: Text('IDR - Rupiah Indonesia (Rp)')),
                    DropdownMenuItem(value: 'USD', child: Text('USD - United States Dollar (\$)')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro (€)')),
                    DropdownMenuItem(value: 'SGD', child: Text('SGD - Singapore Dollar (S\$)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          currencyCode: val,
                          currencySymbol: val == 'USD' ? '\$' : (val == 'EUR' ? '€' : 'Rp'),
                        );
                        _hasUnsavedChanges = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: settings.dateFormat,
                  decoration: const InputDecoration(
                    labelText: 'Format Tampilan Tanggal',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'd MMMM yyyy', child: Text('18 Oktober 2026 (Format Lengkap)')),
                    DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('18/10/2026 (Format Ringkas)')),
                    DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('2026-10-18 (Format ISO)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings!.copyWith(dateFormat: val);
                        _hasUnsavedChanges = true;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Security & Safety
          AppCard(
            title: 'Keamanan & Kebijakan Data',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Konfirmasi Dialog Sebelum Menghapus Data'),
                  subtitle: const Text('Menampilkan jendela konfirmasi sebelum menghapus VPS, tagihan, atau pelanggan'),
                  value: settings.confirmBeforeDelete,
                  onChanged: (val) {
                    setState(() {
                      _settings = _settings!.copyWith(confirmBeforeDelete: val);
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
                const Divider(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: settings.autoLockMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Kunci Sesi Otomatis (Auto-Lock)',
                    prefixIcon: Icon(Icons.lock_clock_rounded),
                    helperText: 'Otomatis meminta login ulang jika tidak ada aktivitas pengguna',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Tidak Aktif (Selalu Buka)')),
                    DropdownMenuItem(value: 5, child: Text('5 Menit')),
                    DropdownMenuItem(value: 15, child: Text('15 Menit')),
                    DropdownMenuItem(value: 30, child: Text('30 Menit')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _settings = _settings!.copyWith(autoLockMinutes: val);
                        _hasUnsavedChanges = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_rounded, color: AppColors.warning),
                  title: const Text('Ganti Kata Sandi & Kelola Akun Pribadi'),
                  subtitle: const Text('Kelola data profil, email, dan password Anda di Halaman Profil'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 6: DATABASE & DIAGNOSTIK
  // ===========================================================================
  Widget _buildDatabaseDiagnosticsTab(
    SystemSettingsModel settings,
    bool isDark,
    Color primaryAccent,
    bool isDesktop,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Firestore Collections Stats
          AppCard(
            title: 'Ringkasan & Statistik Dokumen Database',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jumlah dokumen tersimpan di Cloud Firestore:',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    IconButton(
                      icon: _isLoadingStats
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: 'Hitung Ulang Statistik',
                      onPressed: _isLoadingStats ? null : _loadDatabaseStats,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricChip('Pelanggan', _dbStats?.totalCustomers ?? 0, Icons.people_rounded, primaryAccent),
                    _buildMetricChip('Layanan VPS', _dbStats?.totalServices ?? 0, Icons.dns_rounded, AppColors.electricBlue),
                    _buildMetricChip('Invoice Tagihan', _dbStats?.totalInvoices ?? 0, Icons.receipt_long_rounded, AppColors.warning),
                    _buildMetricChip('Pengeluaran', _dbStats?.totalExpenses ?? 0, Icons.money_off_csred_rounded, AppColors.danger),
                    _buildMetricChip('Log Audit', _dbStats?.totalAuditLogs ?? 0, Icons.history_rounded, AppColors.info),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Ekspor Cadangan Lengkap Sistem (JSON Backup)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _handleExportBackupJson,
                  ),
                ),
              ],
            ),
          ),


          // Infrastructure Backend & Firebase Card
          AppCard(
            title: 'Infrastruktur Backend & Firebase',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                _buildSettingRow(
                  context,
                  'Lokasi Server / Region',
                  'asia-southeast1 (Jakarta/SG)',
                  icon: Icons.language_rounded,
                ),
                const Divider(height: 16),
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
                          : (_latencyMs != null
                              ? 'Uji Ulang Koneksi Latensi Firebase'
                              : 'Uji Koneksi Backend Firebase'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Catalog Maintenance
          AppCard(
            title: 'Katalog & Pemeliharaan Paket Referensi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inisialisasi ulang paket katalog referensi bawaan (Basic, Standard, Semi Pro, Pro, Snipe-it) ke Firestore:',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  icon: _isSeedingCatalog
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(_isSeedingCatalog ? 'Menyinkronkan...' : 'Sinkronkan Katalog Paket Standar'),
                  onPressed: _isSeedingCatalog
                      ? null
                      : () async {
                          setState(() => _isSeedingCatalog = true);
                          try {
                            await ref.read(packageRepositoryProvider).seedDefaultPackages();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Paket referensi berhasil disinkronkan ke Firestore.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSeedingCatalog = false);
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, int count, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              Text(
                '$count Dokumen',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportBackupJson() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Menyiapkan cadangan data JSON...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final jsonStr = await ref.read(settingsRepositoryProvider).exportSystemBackupJson();
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showBackupResultDialog(jsonStr);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor data: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showBackupResultDialog(String jsonStr) {
    final bytes = utf8.encode(jsonStr).length;
    final sizeKb = (bytes / 1024).toStringAsFixed(1);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.file_download_done_rounded, color: AppColors.success),
            const SizedBox(width: 8),
            Text('Cadangan Sistem Siap ($sizeKb KB)'),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Data seluruh koleksi (Pelanggan, VPS, Tagihan, Pengeluaran, dan Pengaturan) berhasil diekstrak menjadi format JSON terstruktur.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0C131D)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonStr.substring(0, jsonStr.length > 1200 ? 1200 : jsonStr.length) +
                        (jsonStr.length > 1200 ? '\n... (dan seterusnya)' : ''),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin Seluruh JSON ke Clipboard'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cadangan JSON ($sizeKb KB) berhasil disalin ke clipboard!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

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
