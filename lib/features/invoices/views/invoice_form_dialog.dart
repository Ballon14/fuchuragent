import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_model.dart';
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pelanggan terlebih dahulu')),
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
                if (widget.preselectedCustomerId == null)
                  StreamBuilder(
                    stream: customersAsync,
                    builder: (context, snapshot) {
                      final list = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedCustomerId,
                        decoration: const InputDecoration(labelText: 'Pilih Pelanggan *'),
                        items: list.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.phone})'));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCustomerId = val),
                        validator: (v) => v == null ? 'Pilih pelanggan' : null,
                      );
                    },
                  ),
                const SizedBox(height: 14),

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
