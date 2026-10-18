import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/customer_model.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  final CustomerModel? customer;

  const CustomerFormDialog({super.key, this.customer});

  static Future<CustomerModel?> show(BuildContext context, {CustomerModel? customer}) {
    return showDialog<CustomerModel>(
      context: context,
      builder: (ctx) => CustomerFormDialog(customer: customer),
    );
  }

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _sourceIdCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _notesCtrl;
  bool _isGeneratingId = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _sourceIdCtrl = TextEditingController(text: c?.sourceId ?? '');
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');

    // Auto-generate customer ID if creating new customer or if ID is empty
    if (widget.customer == null || (c != null && c.sourceId.trim().isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoGenerateId();
      });
    }
  }

  Future<void> _autoGenerateId() async {
    if (!mounted) return;
    setState(() => _isGeneratingId = true);
    try {
      final nextId = await ref.read(customerRepositoryProvider).generateNextCustomerId();
      if (mounted) {
        setState(() {
          _sourceIdCtrl.text = nextId;
          _isGeneratingId = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingId = false);
      }
    }
  }

  @override
  void dispose() {
    _sourceIdCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final customerName = _nameCtrl.text.trim();
    final isEdit = widget.customer != null;

    final confirmed = isEdit
        ? await ConfirmationDialog.showUpdateConfirmation(
            context: context,
            title: 'Konfirmasi Perubahan Pelanggan',
            itemName: customerName,
            detail: 'ID: ${_sourceIdCtrl.text.trim()} | Kontak: ${_phoneCtrl.text.trim()}',
          )
        : await ConfirmationDialog.showCreateConfirmation(
            context: context,
            title: 'Konfirmasi Tambah Pelanggan Baru',
            itemName: customerName,
            detail: 'ID: ${_sourceIdCtrl.text.trim()} | Kontak: ${_phoneCtrl.text.trim()}',
          );

    if (!confirmed || !mounted) return;

    // Clean phone number
    String rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.startsWith('08')) {
      rawPhone = '628${rawPhone.substring(2)}';
    } else if (rawPhone.startsWith('+62')) {
      rawPhone = rawPhone.substring(1);
    }

    final result = CustomerModel(
      id: widget.customer?.id ?? '',
      sourceId: _sourceIdCtrl.text.trim(),
      name: customerName,
      phone: rawPhone,
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      status: widget.customer?.status ?? 'inactive',
      notes: _notesCtrl.text.trim(),
      createdAt: widget.customer?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(result);
  }

  Widget _buildCustomerIdField(bool isDark, Color primaryColor) {
    return TextFormField(
      controller: _sourceIdCtrl,
      decoration: InputDecoration(
        labelText: 'ID Pelanggan (Otomatis) *',
        hintText: 'CUS-021',
        prefixIcon: Icon(Icons.tag_rounded, size: 20, color: primaryColor),
        helperText: 'Otomatis dihitung dari urutan data terakhir',
        suffixIcon: _isGeneratingId
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Generate Ulang ID Baru',
                onPressed: _autoGenerateId,
              ),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'ID Pelanggan wajib diisi' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
              color: primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Data Pelanggan' : 'Tambah Pelanggan Baru',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  isEdit ? 'Perbarui informasi kontak & identitas pelanggan' : 'Daftarkan kontak pelanggan penyewa VPS Fuchur Agent',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Box regarding Dynamic Status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Status pelanggan (Aktif / Nonaktif) ditentukan secara dinamis berdasarkan masa berlaku layanan VPS yang disewa.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap / Instansi *',
                    hintText: 'Contoh: PT Teknologi Bangsa atau Budi Santoso',
                    prefixIcon: Icon(Icons.badge_rounded, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 14),

                // Phone & Customer ID
                if (isMobile) ...[
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp / HP *',
                      hintText: '08123456789 atau 628123456789',
                      helperText: 'Otomatis dihubungkan untuk notifikasi tagihan & jatuh tempo',
                      prefixIcon: Icon(Icons.phone_android_rounded, size: 20),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor telepon wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildCustomerIdField(isDark, primaryColor),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Nomor WhatsApp / HP *',
                            hintText: '08123456789',
                            helperText: 'Notifikasi invoice & WhatsApp',
                            prefixIcon: Icon(Icons.phone_android_rounded, size: 20),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor telepon wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCustomerIdField(isDark, primaryColor),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Email (Opsional)',
                    hintText: 'admin@perusahaan.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),

                // Notes
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Internal (Opsional)',
                    hintText: 'Kebutuhan server khusus, kontak PIC cadangan, dll.',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          icon: Icon(isEdit ? Icons.check_circle_rounded : Icons.person_add_rounded, size: 18),
          label: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Pelanggan'),
          onPressed: _submit,
        ),
      ],
    );
  }
}
