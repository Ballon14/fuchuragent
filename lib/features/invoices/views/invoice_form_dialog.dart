import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_model.dart';
import '../../customers/models/customer_model.dart';
import '../../customers/views/customer_search_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';

class InvoiceFormDialog extends ConsumerStatefulWidget {
  final String? preselectedCustomerId;
  final String? preselectedServiceId;
  final int? suggestedAmount;

  const InvoiceFormDialog({
    super.key,
    this.preselectedCustomerId,
    this.preselectedServiceId,
    this.suggestedAmount,
  });

  static Future<InvoiceModel?> show(
    BuildContext context, {
    String? preselectedCustomerId,
    String? preselectedServiceId,
    int? suggestedAmount,
  }) {
    return showDialog<InvoiceModel>(
      context: context,
      builder: (ctx) => InvoiceFormDialog(
        preselectedCustomerId: preselectedCustomerId,
        preselectedServiceId: preselectedServiceId,
        suggestedAmount: suggestedAmount,
      ),
    );
  }

  @override
  ConsumerState<InvoiceFormDialog> createState() => _InvoiceFormDialogState();
}

class _InvoiceFormDialogState extends ConsumerState<InvoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  String? _selectedServiceId;
  final _itemDescCtrl = TextEditingController(text: 'Perpanjangan Layanan VPS');
  final _unitPriceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _discountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.preselectedCustomerId;
    _selectedServiceId = widget.preselectedServiceId;
    _unitPriceCtrl.text = widget.suggestedAmount != null ? widget.suggestedAmount.toString() : '80000';
  }

  @override
  void dispose() {
    _itemDescCtrl.dispose();
    _unitPriceCtrl.dispose();
    _quantityCtrl.dispose();
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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

    final unitPrice = int.tryParse(_unitPriceCtrl.text) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text) ?? 1;
    final discount = int.tryParse(_discountCtrl.text) ?? 0;
    final subtotal = unitPrice * quantity;
    final total = (subtotal - discount).clamp(0, double.infinity).toInt();

    final item = InvoiceItem(
      description: _itemDescCtrl.text.trim(),
      unitPrice: unitPrice,
      quantity: quantity,
      total: subtotal,
    );

    final invoice = InvoiceModel(
      id: '',
      invoiceNumber: '',
      customerId: _selectedCustomerId!,
      serviceId: _selectedServiceId,
      items: [item],
      subtotal: subtotal,
      discount: discount,
      total: total,
      paidAmount: 0,
      status: 'unpaid',
      issuedAt: DateTime.now(),
      dueDate: _dueDate,
      notes: _notesCtrl.text.trim(),
    );

    Navigator.of(context).pop(invoice);
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerRepositoryProvider).watchCustomers();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return AlertDialog(
      title: const Text('Buat Tagihan Baru'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                  'Belum ada data pelanggan untuk ditagih.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  ),
                                ),
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
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _itemDescCtrl,
                  decoration: const InputDecoration(labelText: 'Deskripsi Item Tagihan *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Deskripsi wajib diisi' : null,
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unitPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Harga Satuan (IDR) *'),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Nominal harus angka' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty *'),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Qty angka' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _discountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Potongan / Diskon (IDR)'),
                ),
                const SizedBox(height: 14),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal Jatuh Tempo', style: TextStyle(fontSize: 12)),
                  subtitle: Text(AppConstants.formatDate(_dueDate)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan Tagihan'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(onPressed: _submit, child: const Text('Terbitkan Tagihan')),
      ],
    );
  }
}
