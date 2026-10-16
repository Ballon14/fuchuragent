import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import '../../packages/models/package_model.dart';
import '../../customers/models/customer_model.dart';
import '../../customers/views/customer_form_dialog.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';

class ServiceFormDialog extends ConsumerStatefulWidget {
  final VpsServiceModel? service;
  final String? preselectedCustomerId;

  const ServiceFormDialog({super.key, this.service, this.preselectedCustomerId});

  static Future<VpsServiceModel?> show(BuildContext context, {VpsServiceModel? service, String? preselectedCustomerId}) {
    return showDialog<VpsServiceModel>(
      context: context,
      builder: (ctx) => ServiceFormDialog(service: service, preselectedCustomerId: preselectedCustomerId),
    );
  }

  @override
  ConsumerState<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends ConsumerState<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _domainCtrl;
  late TextEditingController _serviceNameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _vcpuCtrl;
  late TextEditingController _ramCtrl;
  late TextEditingController _storageCtrl;
  late TextEditingController _workerCtrl;
  late TextEditingController _notesCtrl;

  String? _selectedCustomerId;
  String _selectedPackageName = 'Basic';
  String _status = 'active';
  String _deploymentType = 'Publish';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _workerPaid = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _selectedCustomerId = widget.preselectedCustomerId ?? s?.customerId;
    _domainCtrl = TextEditingController(text: s?.domain ?? '');
    _serviceNameCtrl = TextEditingController(text: s?.serviceName ?? '');
    _priceCtrl = TextEditingController(text: s?.price != null ? s!.price.toString() : '80000');
    _vcpuCtrl = TextEditingController(text: s?.vcpu != null ? s!.vcpu.toString() : '1');
    _ramCtrl = TextEditingController(text: s?.ramGb != null ? s!.ramGb.toString() : '1');
    _storageCtrl = TextEditingController(text: s?.storageGb != null ? s!.storageGb.toString() : '20');
    _workerCtrl = TextEditingController(text: s?.worker ?? 'Iqbal');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    if (s != null) {
      _selectedPackageName = s.packageName;
      _status = s.status;
      _deploymentType = s.deploymentType;
      _startDate = s.startDate ?? DateTime.now();
      _endDate = s.endDate ?? DateTime.now().add(const Duration(days: 30));
      _workerPaid = s.workerPaid;
    }
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _serviceNameCtrl.dispose();
    _priceCtrl.dispose();
    _vcpuCtrl.dispose();
    _ramCtrl.dispose();
    _storageCtrl.dispose();
    _workerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onPackageSelected(VpsPackageModel pkg) {
    setState(() {
      _selectedPackageName = pkg.name;
      _vcpuCtrl.text = pkg.vcpu.toString();
      _ramCtrl.text = pkg.ramGb.toString();
      _storageCtrl.text = pkg.storageGb.toString();
      _priceCtrl.text = pkg.basePrice.toString();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pelanggan terlebih dahulu')),
      );
      return;
    }

    final domain = _domainCtrl.text.trim();
    final serviceName = _serviceNameCtrl.text.trim().isNotEmpty
        ? _serviceNameCtrl.text.trim()
        : 'VPS ${domain.replaceAll("https://", "").replaceAll("http://", "")}';

    final result = VpsServiceModel(
      id: widget.service?.id ?? '',
      customerId: _selectedCustomerId!,
      serviceName: serviceName,
      domain: domain,
      packageName: _selectedPackageName,
      vcpu: int.tryParse(_vcpuCtrl.text) ?? 1,
      ramGb: int.tryParse(_ramCtrl.text) ?? 1,
      storageGb: int.tryParse(_storageCtrl.text) ?? 20,
      price: int.tryParse(_priceCtrl.text) ?? 0,
      billingCycleMonths: 1,
      startDate: _startDate,
      endDate: _endDate,
      status: _status,
      deploymentType: _deploymentType,
      worker: _workerCtrl.text.trim().isNotEmpty ? _workerCtrl.text.trim() : null,
      workerPaid: _workerPaid,
      notes: _notesCtrl.text.trim(),
      createdAt: widget.service?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerRepositoryProvider).watchCustomers();
    final packages = List<VpsPackageModel>.from(VpsPackageModel.defaultCatalog)
      ..sort((a, b) => a.basePrice.compareTo(b.basePrice));
    final isEdit = widget.service != null;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Layanan VPS' : 'Tambah Layanan VPS Baru'),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer selector
                if (widget.preselectedCustomerId == null) ...[
                  StreamBuilder<List<CustomerModel>>(
                    stream: customersAsync,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: LinearProgressIndicator(color: AppColors.cyan, minHeight: 2),
                        );
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Gagal memuat pelanggan: ${snapshot.error}',
                            style: const TextStyle(color: AppColors.danger, fontSize: 12),
                          ),
                        );
                      }

                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Belum ada data pelanggan.',
                                  style: TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final newCust = await CustomerFormDialog.show(context);
                                  if (newCust != null) {
                                    await ref.read(customerRepositoryProvider).addCustomer(newCust);
                                    setState(() => _selectedCustomerId = newCust.id);
                                  }
                                },
                                child: const Text('Tambah', style: TextStyle(color: AppColors.cyan, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }

                      final effectiveValue = list.any((c) => c.id == _selectedCustomerId) ? _selectedCustomerId : null;

                      return DropdownButtonFormField<String>(
                        key: ValueKey(effectiveValue),
                        initialValue: effectiveValue,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Pilih Pelanggan *'),
                        items: list.map((c) {
                          final phoneInfo = c.phone.isNotEmpty ? ' (${c.phone})' : '';
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              '${c.name}$phoneInfo',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCustomerId = val),
                        validator: (v) => v == null ? 'Pilih pelanggan terlebih dahulu' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Package quick select chips
                const Text('Pilih Template Paket VPS:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: packages.map((pkg) {
                    final selected = _selectedPackageName == pkg.name;
                    return ChoiceChip(
                      label: Text(pkg.name, style: TextStyle(fontSize: 11, color: selected ? Colors.black : Colors.white)),
                      selected: selected,
                      onSelected: (_) => _onPackageSelected(pkg),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _domainCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Domain / Hostname (FQDN) *',
                    hintText: 'https://mysite.buildsys.site',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Domain wajib diisi' : null,
                ),
                const SizedBox(height: 14),

                if (isMobile) ...[
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga Sewa (IDR/Bln) *'),
                    validator: (v) => (v == null || int.tryParse(v) == null) ? 'Harga angka tidak valid' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status Layanan'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Aktif')),
                      DropdownMenuItem(value: 'deactive', child: Text('Nonaktif')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'suspended', child: Text('Ditangguhkan')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _status = val);
                    },
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Harga Sewa (IDR/Bln) *'),
                          validator: (v) => (v == null || int.tryParse(v) == null) ? 'Harga angka tidak valid' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(labelText: 'Status Layanan'),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Aktif')),
                            DropdownMenuItem(value: 'deactive', child: Text('Nonaktif')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'suspended', child: Text('Ditangguhkan')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Specs: vCPU, RAM, Storage
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
                const SizedBox(height: 14),

                // Dates: Start and End
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mulai Aktif', style: TextStyle(fontSize: 12)),
                        subtitle: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                        trailing: const Icon(Icons.calendar_today, size: 16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _startDate = picked);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Jatuh Tempo', style: TextStyle(fontSize: 12)),
                        subtitle: Text('${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                        trailing: const Icon(Icons.calendar_today, size: 16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _endDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Worker info
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _workerCtrl,
                        decoration: const InputDecoration(labelText: 'Worker / Staf Teknis'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Honor Worker Lunas', style: TextStyle(fontSize: 12)),
                        value: _workerPaid,
                        onChanged: (v) => setState(() => _workerPaid = v ?? false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan Teknis'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(onPressed: _submit, child: Text(isEdit ? 'Simpan' : 'Tambah Layanan')),
      ],
    );
  }
}
