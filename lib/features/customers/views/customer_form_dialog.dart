import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../models/customer_model.dart';

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final result = CustomerModel(
      id: widget.customer?.id ?? '',
      sourceId: _sourceIdCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      status: widget.customer?.status ?? 'inactive',
      notes: _notesCtrl.text.trim(),
      createdAt: widget.customer?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(result);
  }

  Widget _buildCustomerIdField() {
    return TextFormField(
      controller: _sourceIdCtrl,
      decoration: InputDecoration(
        labelText: 'ID Pelanggan (Otomatis) *',
        hintText: 'Contoh: CUS-021',
        helperText: 'Digenerate otomatis (dapat diubah jika perlu)',
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
                tooltip: 'Generate Ulang ID',
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

    return AlertDialog(
      title: Text(isEdit ? 'Edit Pelanggan' : 'Tambah Pelanggan Baru'),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap / Instansi *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                if (isMobile) ...[
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Nomor WhatsApp / HP *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor telepon wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),
                  _buildCustomerIdField(),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Nomor WhatsApp / HP *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor telepon wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCustomerIdField(),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email (Opsional)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Catatan Internal'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Pelanggan'),
        ),
      ],
    );
  }
}
