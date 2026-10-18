import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import '../../packages/models/package_model.dart';
import '../../customers/models/customer_model.dart';
import '../../customers/views/customer_form_dialog.dart';
import '../../customers/views/customer_search_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
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

  Future<void> _openCustomerSearch() async {
    final picked = await CustomerSearchDialog.show(
      context,
      selectedCustomerId: _selectedCustomerId,
    );
    if (picked != null) {
      setState(() {
        _selectedCustomerId = picked.id;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih pelanggan terlebih dahulu melalui tombol Cari Pelanggan.'),
          backgroundColor: AppColors.danger,
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

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
                // Customer selector with Search Action
                if (widget.preselectedCustomerId == null) ...[
                  StreamBuilder<List<CustomerModel>>(
                    stream: customersAsync,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: LinearProgressIndicator(color: primaryColor, minHeight: 2),
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
                              Expanded(
                                child: Text(
                                  'Belum ada data pelanggan.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final newCust = await CustomerFormDialog.show(context);
                                  if (newCust != null) {
                                    final createdId = await ref.read(customerRepositoryProvider).addCustomer(newCust);
                                    setState(() => _selectedCustomerId = createdId);
                                  }
                                },
                                child: Text('Tambah', style: TextStyle(color: primaryColor, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }

                      CustomerModel? selectedCustomer;
                      if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
                        try {
                          selectedCustomer = list.firstWhere((c) => c.id == _selectedCustomerId);
                        } catch (_) {
                          selectedCustomer = null;
                        }
                      }

                      if (selectedCustomer != null) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: primaryColor.withValues(alpha: 0.2),
                                child: Text(
                                  selectedCustomer.name.isNotEmpty ? selectedCustomer.name[0].toUpperCase() : 'C',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            selectedCustomer.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (selectedCustomer.sourceId.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              selectedCustomer.sourceId,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone_rounded,
                                          size: 12,
                                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          selectedCustomer.phone,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(status: selectedCustomer.status),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                label: const Text('Ganti'),
                                onPressed: _openCustomerSearch,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return InkWell(
                        onTap: _openCustomerSearch,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceLightDark : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.person_search_rounded, color: primaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pilih Pelanggan *',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Klik untuk mencari nama, WhatsApp, ID...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _openCustomerSearch,
                                icon: const Icon(Icons.search_rounded, size: 16),
                                label: const Text('Cari'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Package quick select chips
                Text(
                  'Pilih Template Paket VPS:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: packages.map((pkg) {
                    final selected = _selectedPackageName == pkg.name;
                    return ChoiceChip(
                      label: Text(
                        pkg.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ),
                      selected: selected,
                      selectedColor: primaryColor,
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
