import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_model.dart';
import '../../invoices/models/invoice_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class RecordPaymentDialog extends ConsumerStatefulWidget {
  final String? preselectedInvoiceId;
  final int? suggestedAmount;

  const RecordPaymentDialog({
    super.key,
    this.preselectedInvoiceId,
    this.suggestedAmount,
  });

  static Future<PaymentModel?> show(
    BuildContext context, {
    String? preselectedInvoiceId,
    int? suggestedAmount,
  }) {
    return showDialog<PaymentModel>(
      context: context,
      builder: (ctx) => RecordPaymentDialog(
        preselectedInvoiceId: preselectedInvoiceId,
        suggestedAmount: suggestedAmount,
      ),
    );
  }

  @override
  ConsumerState<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedInvoiceId;
  late TextEditingController _amountCtrl;
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'Transfer Bank BCA';
  bool _isLoading = false;

  final List<String> _methods = [
    'Transfer Bank BCA',
    'Transfer Bank Mandiri',
    'Transfer Bank BNI',
    'Transfer Bank BRI',
    'QRIS / GoPay / OVO',
    'Tunai (Cash)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedInvoiceId = widget.preselectedInvoiceId;
    _amountCtrl = TextEditingController(
      text: widget.suggestedAmount != null ? widget.suggestedAmount.toString() : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInvoiceId == null || _selectedInvoiceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tagihan yang akan dibayar')),
      );
      return;
    }

    final amount = int.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pembayaran harus lebih dari 0')),
      );
      return;
    }

    final confirmed = await ConfirmationDialog.showCreateConfirmation(
      context: context,
      title: 'Konfirmasi Catat Pembayaran',
      itemName: 'Pembayaran Tagihan',
      detail:
          'Nominal: ${AppConstants.formatRupiah(amount)} ($_paymentMethod)${_refCtrl.text.trim().isNotEmpty ? " | Ref: ${_refCtrl.text.trim()}" : ""}',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final payment = await ref.read(paymentRepositoryProvider).recordPayment(
            invoiceId: _selectedInvoiceId!,
            amount: amount,
            paymentMethod: _paymentMethod,
            referenceNumber: _refCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop(payment);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencatat pembayaran: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoiceRepositoryProvider).watchInvoices(statusFilter: 'unpaid');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final settings = ref.watch(systemSettingsProvider).asData?.value;
    final dynamicMethods = settings?.paymentMethods
        .where((p) => p.isActive)
        .map((p) => p.formattedDisplay)
        .toList() ?? [];

    final availableMethods = dynamicMethods.isNotEmpty ? dynamicMethods : _methods;
    final currentMethod = availableMethods.contains(_paymentMethod)
        ? _paymentMethod
        : availableMethods.first;

    return AlertDialog(
      title: const Text('Catat Pembayaran Tagihan'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.preselectedInvoiceId == null) ...[
                  StreamBuilder<List<InvoiceModel>>(
                    stream: invoicesAsync,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: LinearProgressIndicator(color: primaryColor, minHeight: 2),
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
                                  'Tidak ada tagihan yang belum lunas.',
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

                      final effectiveValue = list.any((inv) => inv.id == _selectedInvoiceId) ? _selectedInvoiceId : null;

                      return DropdownButtonFormField<String>(
                        key: ValueKey(effectiveValue),
                        initialValue: effectiveValue,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Pilih Tagihan Terbuka *'),
                        items: list.map((inv) {
                          return DropdownMenuItem<String>(
                            value: inv.id,
                            child: Text(
                              '${inv.invoiceNumber} (Sisa: ${AppConstants.formatRupiah(inv.remainingBalance)})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedInvoiceId = val;
                            if (val != null) {
                              final matches = list.where((i) => i.id == val);
                              if (matches.isNotEmpty) {
                                _amountCtrl.text = matches.first.remainingBalance.toString();
                              }
                            }
                          });
                        },
                        validator: (v) => v == null ? 'Pilih tagihan' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal Pembayaran (IDR) *',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) => (v == null || int.tryParse(v) == null) ? 'Nominal harus angka' : null,
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  key: ValueKey(currentMethod),
                  initialValue: currentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Metode Pembayaran & Rekening *',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: availableMethods.map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentMethod = v);
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Referensi Transaksi / Kode Mutasi',
                    hintText: 'TRX-10293847',
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Catatan Pembayaran'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                )
              : const Text('Simpan Pembayaran'),
        ),
      ],
    );
  }
}
