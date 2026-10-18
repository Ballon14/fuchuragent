import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/expense_model.dart';

class ExpenseFormDialog extends ConsumerStatefulWidget {
  final ExpenseModel? expense;

  const ExpenseFormDialog({super.key, this.expense});

  static Future<ExpenseModel?> show(BuildContext context, {ExpenseModel? expense}) {
    return showDialog<ExpenseModel>(
      context: context,
      builder: (ctx) => ExpenseFormDialog(expense: expense),
    );
  }

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numberCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _recipientCtrl;
  late TextEditingController _notesCtrl;

  late String _category;
  late String _paymentMethod;
  late DateTime _expenseDate;
  bool _isLoading = false;
  bool _isGeneratingNumber = false;

  final List<String> _categories = [
    'SERVER',
    'LICENSE',
    'WORKER',
    'DOMAIN',
    'NETWORK',
    'OPERATIONAL',
    'OTHER',
  ];

  final List<String> _paymentMethods = [
    'Transfer Bank BCA',
    'Transfer Bank Mandiri',
    'Transfer Bank BNI',
    'Transfer Bank BRI',
    'PayPal',
    'Kartu Kredit / Debit',
    'QRIS / E-Wallet',
    'Tunai (Cash)',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _numberCtrl = TextEditingController(text: e?.expenseNumber ?? '');
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _amountCtrl = TextEditingController(text: e != null && e.amount > 0 ? e.amount.toString() : '');
    _recipientCtrl = TextEditingController(text: e?.recipient ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');

    _category = e?.category ?? 'SERVER';
    _paymentMethod = e?.paymentMethod.isNotEmpty == true ? e!.paymentMethod : 'Transfer Bank BCA';
    _expenseDate = e?.expenseDate ?? DateTime.now();

    if (widget.expense == null || (e != null && e.expenseNumber.trim().isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoGenerateNumber();
      });
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _recipientCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoGenerateNumber() async {
    if (!mounted) return;
    setState(() => _isGeneratingNumber = true);
    try {
      final nextNum = await ref.read(expenseRepositoryProvider).generateNextExpenseNumber();
      if (mounted) {
        setState(() {
          _numberCtrl.text = nextNum;
          _isGeneratingNumber = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGeneratingNumber = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pengeluaran harus lebih besar dari 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expenseRepo = ref.read(expenseRepositoryProvider);
      ExpenseModel saved;

      if (widget.expense == null) {
        final newExpense = ExpenseModel(
          id: '',
          expenseNumber: _numberCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          category: _category,
          amount: amount,
          expenseDate: _expenseDate,
          recipient: _recipientCtrl.text.trim(),
          paymentMethod: _paymentMethod,
          notes: _notesCtrl.text.trim(),
        );
        final id = await expenseRepo.addExpense(newExpense);
        saved = newExpense.copyWith(id: id);
      } else {
        final updatedExpense = widget.expense!.copyWith(
          expenseNumber: _numberCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          category: _category,
          amount: amount,
          expenseDate: _expenseDate,
          recipient: _recipientCtrl.text.trim(),
          paymentMethod: _paymentMethod,
          notes: _notesCtrl.text.trim(),
        );
        await expenseRepo.updateExpense(updatedExpense);
        saved = updatedExpense;
      }

      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan pengeluaran: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    final isEdit = widget.expense != null;
    final settings = ref.watch(systemSettingsProvider).asData?.value;
    final activeDynamicMethods = settings?.paymentMethods
        .where((p) => p.isActive)
        .map((p) => p.formattedDisplay)
        .toList() ?? [];

    final availableMethods = activeDynamicMethods.isNotEmpty
        ? [...activeDynamicMethods, 'PayPal', 'Kartu Kredit / Debit', 'Tunai (Cash)']
        : _paymentMethods;

    final currentPaymentMethod = availableMethods.contains(_paymentMethod)
        ? _paymentMethod
        : availableMethods.first;

    final dummyModel = ExpenseModel(
      id: '',
      title: '',
      category: _category,
      amount: 0,
      expenseDate: _expenseDate,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: dummyModel.categoryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(dummyModel.categoryIcon, color: dummyModel.categoryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Pengeluaran' : 'Catat Pengeluaran Operasional',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isEdit
                                  ? 'Perbarui rincian biaya atau pengeluaran'
                                  : 'Pencatatan kas keluar untuk operasional FuchurHost',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Nomor Pengeluaran & Tanggal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _numberCtrl,
                          decoration: InputDecoration(
                            labelText: 'No. Pengeluaran *',
                            hintText: 'EXP-001',
                            prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                            suffixIcon: _isGeneratingNumber
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    tooltip: 'Generate Nomor Otomatis',
                                    onPressed: _autoGenerateNumber,
                                  ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tanggal Pengeluaran *',
                              prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                            ),
                            child: Text(
                              AppConstants.formatShortDate(_expenseDate),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Judul Pengeluaran
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Judul / Keperluan Pengeluaran *',
                      hintText: 'Contoh: Perpanjangan Server Hetzner AX101',
                      prefixIcon: Icon(Icons.description_rounded, size: 18),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Judul pengeluaran wajib diisi';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Kategori & Nominal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Kategori Biaya *',
                            prefixIcon: Icon(Icons.category_rounded, size: 18),
                          ),
                          items: _categories.map((cat) {
                            final sample = ExpenseModel(
                              id: '',
                              title: '',
                              category: cat,
                              amount: 0,
                              expenseDate: DateTime.now(),
                            );
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(sample.categoryIcon, size: 16, color: sample.categoryColor),
                                  const SizedBox(width: 8),
                                  Text(sample.categoryLabel, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _category = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nominal (IDR) *',
                            hintText: '500000',
                            prefixText: 'Rp ',
                            prefixIcon: Icon(Icons.monetization_on_rounded, size: 18),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Nominal wajib diisi';
                            final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                            if (parsed == null || parsed <= 0) return 'Nominal tidak valid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  // Helper text for formatted nominal
                  if (_amountCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Terbaca: ${AppConstants.formatRupiah(int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryAccent,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Vendor / Penerima & Metode Pembayaran
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _recipientCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Vendor / Penerima',
                            hintText: 'Hetzner, Worker Iqbal, dll.',
                            prefixIcon: Icon(Icons.person_pin_rounded, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(currentPaymentMethod),
                          initialValue: currentPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Metode Pembayaran & Rekening',
                            prefixIcon: Icon(Icons.payment_rounded, size: 18),
                          ),
                          items: availableMethods.map((m) {
                            return DropdownMenuItem<String>(
                              value: m,
                              child: Text(m, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paymentMethod = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Catatan / Keterangan
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Tambahan (Opsional)',
                      hintText: 'No. Invoice vendor, link tiket, atau spesifikasi detail...',
                      prefixIcon: Icon(Icons.notes_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(isEdit ? Icons.check_rounded : Icons.save_rounded, size: 18),
                        label: Text(
                          isEdit ? 'Simpan Perubahan' : 'Catat Pengeluaran',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
