import 'package:flutter/material.dart';
import '../models/customer_model.dart';

class CustomerFormDialog extends StatefulWidget {
  final CustomerModel? customer;

  const CustomerFormDialog({super.key, this.customer});

  static Future<CustomerModel?> show(BuildContext context, {CustomerModel? customer}) {
    return showDialog<CustomerModel>(
      context: context,
      builder: (ctx) => CustomerFormDialog(customer: customer),
    );
  }

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _sourceIdCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _notesCtrl;
  late String _status;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _sourceIdCtrl = TextEditingController(text: c?.sourceId ?? '');
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _status = c?.status ?? 'active';
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
      status: _status,
      notes: _notesCtrl.text.trim(),
      createdAt: widget.customer?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Pelanggan' : 'Tambah Pelanggan Baru'),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 480,
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
                  TextFormField(
                    controller: _sourceIdCtrl,
                    decoration: const InputDecoration(labelText: 'ID Sumber (misal: Cus-020)'),
                  ),
                ] else ...[
                  Row(
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
                        child: TextFormField(
                          controller: _sourceIdCtrl,
                          decoration: const InputDecoration(labelText: 'ID Sumber (misal: Cus-020)'),
                        ),
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
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status Pelanggan'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Aktif')),
                    DropdownMenuItem(value: 'inactive', child: Text('Nonaktif')),
                    DropdownMenuItem(value: 'archived', child: Text('Diarsipkan')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
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
