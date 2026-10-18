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
import '../../../shared/widgets/confirmation_dialog.dart';

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
  late TextEditingController _setupFeeCtrl;
  late TextEditingController _vcpuCtrl;
  late TextEditingController _ramCtrl;
  late TextEditingController _storageCtrl;
  late TextEditingController _workerCtrl;
  late TextEditingController _notesCtrl;

  String? _selectedCustomerId;
  String _selectedPackageName = 'Basic 1 Bulan';
  String _status = 'active';
  String _deploymentType = 'Project Running / Public';
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
    _priceCtrl = TextEditingController(text: s?.price != null ? s!.price.toString() : '76000');
    _setupFeeCtrl = TextEditingController(text: s?.setupFee != null ? s!.setupFee.toString() : '10000');
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
    _setupFeeCtrl.dispose();
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

      final lowerName = pkg.name.toLowerCase();
      if (lowerName.contains('3 bulan') || lowerName.contains('3 bln')) {
        _endDate = _startDate.add(const Duration(days: 90));
      } else if (lowerName.contains('6 bulan') || lowerName.contains('6 bln')) {
        _endDate = _startDate.add(const Duration(days: 180));
      } else if (lowerName.contains('1 tahun') || lowerName.contains('12 bulan') || lowerName.contains('1 thn')) {
        _endDate = _startDate.add(const Duration(days: 365));
      } else if (lowerName.contains('1 bulan') || lowerName.contains('1 bln')) {
        _endDate = _startDate.add(const Duration(days: 30));
      }
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

  Future<void> _submit() async {
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

    final durationDays = _endDate.difference(_startDate).inDays;
    int cycleMonths = 1;
    if (durationDays >= 330) {
      cycleMonths = 12;
    } else if (durationDays >= 150) {
      cycleMonths = 6;
    } else if (durationDays >= 75) {
      cycleMonths = 3;
    } else {
      cycleMonths = 1;
    }

    final cycleLabel = cycleMonths > 1 ? '$cycleMonths Bulan' : '1 Bulan';
    final priceVal = int.tryParse(_priceCtrl.text) ?? 0;
    final setupFeeVal = int.tryParse(_setupFeeCtrl.text) ?? 0;
    final totalInitialVal = priceVal + setupFeeVal;

    final isEdit = widget.service != null;
    final detailText = 'Sewa: ${AppConstants.formatRupiah(priceVal)} / $cycleLabel'
        '${setupFeeVal > 0 ? " | Setup: ${AppConstants.formatRupiah(setupFeeVal)}" : ""}'
        ' | Total Awal: ${AppConstants.formatRupiah(totalInitialVal)}';

    final confirmed = isEdit
        ? await ConfirmationDialog.showUpdateConfirmation(
            context: context,
            title: 'Konfirmasi Perubahan Layanan VPS',
            itemName: '$domain ($_selectedPackageName)',
            detail: detailText,
          )
        : await ConfirmationDialog.showCreateConfirmation(
            context: context,
            title: 'Konfirmasi Tambah Layanan VPS Baru',
            itemName: '$domain ($_selectedPackageName)',
            detail: detailText,
          );

    if (!confirmed || !mounted) return;

    final result = VpsServiceModel(
      id: widget.service?.id ?? '',
      customerId: _selectedCustomerId!,
      serviceName: serviceName,
      domain: domain,
      packageName: _selectedPackageName,
      vcpu: int.tryParse(_vcpuCtrl.text) ?? 1,
      ramGb: int.tryParse(_ramCtrl.text) ?? 1,
      storageGb: int.tryParse(_storageCtrl.text) ?? 20,
      price: priceVal,
      setupFee: setupFeeVal,
      billingCycleMonths: cycleMonths,
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

  Widget _buildSetupPresetChip({
    required String label,
    required int amount,
    required String deploymentType,
    required Color primaryColor,
    required bool isDark,
  }) {
    final currentVal = int.tryParse(_setupFeeCtrl.text) ?? 0;
    final isSelected = currentVal == amount;
    return InkWell(
      onTap: () {
        setState(() {
          _setupFeeCtrl.text = amount.toString();
          _deploymentType = deploymentType;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? AppColors.surfaceLightDark : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle_rounded, size: 13, color: primaryColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationPreset(
    String label,
    int days,
    int months,
    List<VpsPackageModel> packages,
    Color primaryColor,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _endDate = _startDate.add(Duration(days: days));

          // Auto-adjust package selection and price for popular durations
          if (months == 3) {
            final p3 = packages.cast<VpsPackageModel?>().firstWhere(
              (p) => p != null && p.name.toLowerCase().contains('3 bulan'),
              orElse: () => null,
            );
            if (p3 != null &&
                (_selectedPackageName.toLowerCase().contains('basic') ||
                    _selectedPackageName.toLowerCase().contains('1 bulan'))) {
              _selectedPackageName = p3.name;
              _priceCtrl.text = p3.basePrice.toString();
              _vcpuCtrl.text = p3.vcpu.toString();
              _ramCtrl.text = p3.ramGb.toString();
              _storageCtrl.text = p3.storageGb.toString();
            }
          } else if (months == 1) {
            final p1 = packages.cast<VpsPackageModel?>().firstWhere(
              (p) =>
                  p != null &&
                  (p.name.toLowerCase().contains('basic 1 bulan') ||
                      p.name.toLowerCase() == 'basic'),
              orElse: () => null,
            );
            if (p1 != null && _selectedPackageName.toLowerCase().contains('3 bulan')) {
              _selectedPackageName = p1.name;
              _priceCtrl.text = p1.basePrice.toString();
              _vcpuCtrl.text = p1.vcpu.toString();
              _ramCtrl.text = p1.ramGb.toString();
              _storageCtrl.text = p1.storageGb.toString();
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerRepositoryProvider).watchCustomers();
    final packagesStream = ref.watch(packageRepositoryProvider).watchPackages();
    final isEdit = widget.service != null;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return StreamBuilder<List<VpsPackageModel>>(
      stream: packagesStream,
      builder: (context, pkgSnapshot) {
        final rawPackages = (pkgSnapshot.hasData && pkgSnapshot.data!.isNotEmpty)
            ? pkgSnapshot.data!
            : VpsPackageModel.defaultCatalog;
        final packages = List<VpsPackageModel>.from(rawPackages)
          ..sort((a, b) => a.basePrice.compareTo(b.basePrice));

        final durationDays = _endDate.difference(_startDate).inDays;
        final effectiveCycleText = durationDays >= 330
            ? '1 Tahun'
            : (durationDays >= 150
                ? '6 Bulan'
                : (durationDays >= 75
                    ? '3 Bulan'
                    : '1 Bulan'));

        final priceVal = int.tryParse(_priceCtrl.text) ?? 0;
        final setupFeeVal = int.tryParse(_setupFeeCtrl.text) ?? 0;
        final totalInitialVal = priceVal + setupFeeVal;

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
              isEdit ? Icons.edit_note_rounded : Icons.dns_rounded,
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
                  isEdit ? 'Edit Layanan VPS' : 'Tambah Layanan VPS Baru',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  isEdit ? 'Perbarui konfigurasi & status VPS' : 'Daftarkan server VPS baru untuk pelanggan',
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

                // Package quick select cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Template Paket VPS:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    Text(
                      'Auto-isi spesifikasi & harga',
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: packages.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final pkg = packages[idx];
                      final isSelected = _selectedPackageName == pkg.name;
                      return InkWell(
                        onTap: () => _onPackageSelected(pkg),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 130,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
                                : (isDark ? AppColors.surfaceLightDark : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    pkg.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? primaryColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded, size: 14, color: primaryColor),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${pkg.vcpu} Core • ${pkg.ramGb}GB • ${pkg.storageGb}GB',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppConstants.formatRupiah(pkg.basePrice),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? primaryColor : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _domainCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Domain / Hostname (FQDN) *',
                    hintText: 'mysite.buildsys.site',
                    prefixIcon: Icon(Icons.language_rounded, size: 20),
                  ),
                  onChanged: (val) {
                    if (_serviceNameCtrl.text.isEmpty || _serviceNameCtrl.text.startsWith('VPS ')) {
                      final clean = val.replaceAll(RegExp(r'https?:\/\/'), '').trim();
                      if (clean.isNotEmpty) {
                        _serviceNameCtrl.text = 'VPS $clean';
                      }
                    }
                  },
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Domain wajib diisi' : null,
                ),
                const SizedBox(height: 14),

                if (isMobile) ...[
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Biaya Sewa Layanan (IDR) *',
                      hintText: 'Contoh: 76000 atau 135000',
                      helperText: 'Harga sewa dinamis — dapat disesuaikan manual',
                      prefixIcon: Icon(Icons.payments_outlined, size: 20),
                    ),
                    onChanged: (_) => setState(() {}),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Biaya Sewa Layanan (IDR) *',
                            hintText: 'Contoh: 76000 atau 135000',
                            helperText: 'Harga sewa dinamis — dapat disesuaikan manual',
                            prefixIcon: Icon(Icons.payments_outlined, size: 20),
                          ),
                          onChanged: (_) => setState(() {}),
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

                // Additional Setup Charge Section (Dinamis: Rp 10.000 / Rp 30.000 / Custom)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.build_circle_outlined, size: 16, color: primaryColor),
                              const SizedBox(width: 6),
                              const Text(
                                'Biaya Setup Awal (Additional Charge)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Dinamis / Opsional',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Preset Buttons
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildSetupPresetChip(
                            label: 'Setup Pertama Kali (+Rp 10.000)',
                            amount: 10000,
                            deploymentType: 'Setup Pertama Kali',
                            primaryColor: primaryColor,
                            isDark: isDark,
                          ),
                          _buildSetupPresetChip(
                            label: 'Project Running / Public (+Rp 30.000)',
                            amount: 30000,
                            deploymentType: 'Project Running / Public',
                            primaryColor: primaryColor,
                            isDark: isDark,
                          ),
                          _buildSetupPresetChip(
                            label: 'Tanpa Setup (Rp 0)',
                            amount: 0,
                            deploymentType: 'Tanpa Setup',
                            primaryColor: primaryColor,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Editable Setup Fee Input & Deployment Type
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _setupFeeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Nominal Biaya Setup (IDR)',
                                hintText: '10000 / 30000 / 0',
                                helperText: 'Bisa diubah bebas sesuai kesepakatan',
                                prefixIcon: Icon(Icons.add_task_rounded, size: 18),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(_deploymentType),
                              initialValue: ['Publish', 'Project Running / Public', 'Setup Pertama Kali', 'Tanpa Setup'].contains(_deploymentType)
                                  ? _deploymentType
                                  : 'Project Running / Public',
                              decoration: const InputDecoration(
                                labelText: 'Tipe Deployment',
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Setup Pertama Kali', child: Text('Setup Pertama Kali')),
                                DropdownMenuItem(value: 'Project Running / Public', child: Text('Running / Public')),
                                DropdownMenuItem(value: 'Publish', child: Text('Publish')),
                                DropdownMenuItem(value: 'Tanpa Setup', child: Text('Tanpa Setup')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _deploymentType = val;
                                    if (val == 'Setup Pertama Kali') {
                                      _setupFeeCtrl.text = '10000';
                                    } else if (val == 'Project Running / Public' || val == 'Publish') {
                                      _setupFeeCtrl.text = '30000';
                                    } else if (val == 'Tanpa Setup') {
                                      _setupFeeCtrl.text = '0';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Specs: vCPU, RAM, Storage
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _vcpuCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'vCPU'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _ramCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'RAM (GB)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _storageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Disk (GB)'),
                        onChanged: (_) => setState(() {}),
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
                        subtitle: Text(AppConstants.formatDate(_startDate)),
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
                        subtitle: Text(AppConstants.formatDate(_endDate)),
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

                // Quick Duration Presets (+1 Bulan, +3 Bulan, +6 Bulan, +1 Tahun)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        'Preset Durasi:',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildDurationPreset('+1 Bulan', 30, 1, packages, primaryColor, isDark),
                              const SizedBox(width: 6),
                              _buildDurationPreset('+3 Bulan', 90, 3, packages, primaryColor, isDark),
                              const SizedBox(width: 6),
                              _buildDurationPreset('+6 Bulan', 180, 6, packages, primaryColor, isDark),
                              const SizedBox(width: 6),
                              _buildDurationPreset('+1 Tahun', 365, 12, packages, primaryColor, isDark),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

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
                  decoration: const InputDecoration(labelText: 'Catatan Teknis (Opsional)'),
                ),
                const SizedBox(height: 14),

                // Live Summary Preview Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Paket & Spek:',
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                          ),
                          Text(
                            '$_selectedPackageName (${_vcpuCtrl.text} vCPU / ${_ramCtrl.text}GB / ${_storageCtrl.text}GB)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Masa Sewa:',
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                          ),
                          Text(
                            '${AppConstants.formatDate(_startDate)} s/d ${AppConstants.formatDate(_endDate)} ($effectiveCycleText)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Biaya Sewa ($effectiveCycleText):',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${AppConstants.formatRupiah(priceVal)} / $effectiveCycleText',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ],
                      ),
                      if (setupFeeVal > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Biaya Setup Awal ($_deploymentType):',
                              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                            Text(
                              '+${AppConstants.formatRupiah(setupFeeVal)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Tagihan Pertama:',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            AppConstants.formatRupiah(totalInitialVal),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ],
                      ),
                      if (setupFeeVal > 0) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '(Tagihan perpanjangan berikutnya: ${AppConstants.formatRupiah(priceVal)} / $effectiveCycleText)',
                              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton.icon(
          icon: Icon(isEdit ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, size: 18),
          label: Text(isEdit ? 'Simpan' : 'Tambah Layanan'),
          onPressed: _submit,
        ),
      ],
    );
      },
    );
  }
}
