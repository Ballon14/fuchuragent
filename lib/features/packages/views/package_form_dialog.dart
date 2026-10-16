import 'package:flutter/material.dart';
import '../models/package_model.dart';

class PackageFormDialog extends StatefulWidget {
  final VpsPackageModel? package;

  const PackageFormDialog({super.key, this.package});

  static Future<VpsPackageModel?> show(BuildContext context, {VpsPackageModel? package}) {
    return showDialog<VpsPackageModel>(
      context: context,
      builder: (ctx) => PackageFormDialog(package: package),
    );
  }

  @override
  State<PackageFormDialog> createState() => _PackageFormDialogState();
}

class _PackageFormDialogState extends State<PackageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _vcpuCtrl;
  late TextEditingController _ramCtrl;
  late TextEditingController _storageCtrl;
  late TextEditingController _descCtrl;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final p = widget.package;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _codeCtrl = TextEditingController(text: p?.code ?? '');
    _priceCtrl = TextEditingController(text: p?.basePrice != null ? p!.basePrice.toString() : '');
    _vcpuCtrl = TextEditingController(text: p?.vcpu != null ? p!.vcpu.toString() : '1');
    _ramCtrl = TextEditingController(text: p?.ramGb != null ? p!.ramGb.toString() : '1');
    _storageCtrl = TextEditingController(text: p?.storageGb != null ? p!.storageGb.toString() : '20');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _priceCtrl.dispose();
    _vcpuCtrl.dispose();
    _ramCtrl.dispose();
    _storageCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final result = VpsPackageModel(
      id: widget.package?.id ?? 'pkg-${_nameCtrl.text.toLowerCase().replaceAll(' ', '-')}',
      name: _nameCtrl.text.trim(),
      code: _codeCtrl.text.trim().isNotEmpty ? _codeCtrl.text.trim() : _nameCtrl.text.toLowerCase().replaceAll(' ', '-'),
      vcpu: int.tryParse(_vcpuCtrl.text) ?? 1,
      ramGb: int.tryParse(_ramCtrl.text) ?? 1,
      storageGb: int.tryParse(_storageCtrl.text) ?? 20,
      basePrice: int.tryParse(_priceCtrl.text) ?? 0,
      isActive: _isActive,
      description: _descCtrl.text.trim(),
      durationDiscounts: widget.package?.durationDiscounts ?? {
        1: 0.08,
        3: 0.10,
        6: 0.12,
        12: 0.15,
      },
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.package != null ? 'Edit Paket VPS' : 'Tambah Paket VPS Baru'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Paket * (misal: Standard)'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga Dasar (IDR/Bulan) *'),
                  validator: (v) => (v == null || int.tryParse(v) == null) ? 'Nominal harus angka' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _vcpuCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'vCPU'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _ramCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'RAM (GB)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _storageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Disk (GB)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Keterangan Singkat'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Status Paket Aktif'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
