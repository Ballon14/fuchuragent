import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/models/service_model.dart';
import '../models/renewal_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';

class RenewActionDialog extends ConsumerStatefulWidget {
  final VpsServiceModel service;

  const RenewActionDialog({super.key, required this.service});

  static Future<ServiceRenewalModel?> show(BuildContext context, {required VpsServiceModel service}) {
    return showDialog<ServiceRenewalModel>(
      context: context,
      builder: (ctx) => RenewActionDialog(service: service),
    );
  }

  @override
  ConsumerState<RenewActionDialog> createState() => _RenewActionDialogState();
}

class _RenewActionDialogState extends ConsumerState<RenewActionDialog> {
  int _durationMonths = 1;
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;

  DateTime get _calculatedNewEndDate {
    final oldEndDate = widget.service.endDate ?? DateTime.now();
    final now = DateTime.now();
    final baseDate = oldEndDate.isAfter(now) ? oldEndDate : now;
    return DateTime(
      baseDate.year,
      baseDate.month + _durationMonths,
      baseDate.day,
      baseDate.hour,
      baseDate.minute,
    );
  }

  int get _calculatedPrice {
    return widget.service.price * _durationMonths;
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final renewal = await ref.read(renewalRepositoryProvider).renewService(
            serviceId: widget.service.id,
            durationMonths: _durationMonths,
            notes: _notesCtrl.text.trim(),
          );
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        Navigator.of(context).pop(renewal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Layanan ${widget.service.domain} berhasil diperpanjang hingga ${AppConstants.formatDate(renewal.newEndDate)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperpanjang: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Perpanjang Layanan VPS'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Domain: ${widget.service.domain}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Paket: ${widget.service.packageName}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLightDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jatuh Tempo Saat Ini:', style: TextStyle(fontSize: 12, color: Colors.white60)),
                        Text(AppConstants.formatDate(widget.service.endDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Jatuh Tempo Baru:', style: TextStyle(fontSize: 12, color: AppColors.cyan)),
                        Text(AppConstants.formatDate(_calculatedNewEndDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.cyan)),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimasi Biaya:', style: TextStyle(fontSize: 12, color: Colors.white60)),
                        Text(AppConstants.formatRupiah(_calculatedPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Pilih Durasi Perpanjangan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [1, 3, 6, 12].map((m) {
                  final selected = _durationMonths == m;
                  return ChoiceChip(
                    label: Text('$m Bulan', style: TextStyle(fontSize: 12, color: selected ? Colors.black : Colors.white)),
                    selected: selected,
                    onSelected: (s) {
                      if (s) setState(() => _durationMonths = m);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Catatan Perpanjangan / Referensi Tiket'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Konfirmasi Perpanjangan'),
        ),
      ],
    );
  }
}
