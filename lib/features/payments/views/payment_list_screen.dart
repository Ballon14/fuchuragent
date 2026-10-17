import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/payment_model.dart';
import 'record_payment_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/app_card.dart';

class PaymentListScreen extends ConsumerWidget {
  const PaymentListScreen({super.key});

  Future<void> _handleReversePayment(BuildContext context, WidgetRef ref, PaymentModel p) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan / Koreksi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin membatalkan transaksi sebesar ${AppConstants.formatRupiah(p.amount)}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Alasan Koreksi / Pembatalan *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Batalkan Transaksi'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.isNotEmpty) {
      try {
        await ref.read(paymentRepositoryProvider).reversePayment(
              paymentId: p.id,
              reason: reasonCtrl.text.trim(),
            );
        ref.invalidate(dashboardStatsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pembayaran berhasil dibatalkan dan saldo tagihan dikoreksi.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentRepo = ref.watch(paymentRepositoryProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Future<void> openRecordDialog() async {
      final p = await RecordPaymentDialog.show(context);
      if (p != null) {
        ref.invalidate(dashboardStatsProvider);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pembayaran & Kas'),
        actions: [
          if (isDesktop)
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Catat Pembayaran'),
              onPressed: openRecordDialog,
            )
          else
            IconButton(
              icon: const Icon(Icons.add_card_rounded),
              tooltip: 'Catat Pembayaran',
              onPressed: openRecordDialog,
            ),
          const SizedBox(width: 14),
        ],
      ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
              onPressed: openRecordDialog,
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Catat Kas Masuk', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: paymentRepo.watchPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final payments = snapshot.data ?? [];
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total ${payments.length} Transaksi Tercatat',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 10),
                Expanded(
                  child: payments.isEmpty
                      ? _buildEmptyState(context, ref, openRecordDialog)
                      : (isDesktop ? _buildDesktopTable(context, ref, payments) : _buildMobileList(context, ref, payments)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, VoidCallback onRecord) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments_rounded, size: 64, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('Belum ada transaksi pembayaran yang tercatat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Catat pelunasan atau cicilan dari pelanggan FuchurHost Solutions.',
            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Catat Pembayaran Pertama'),
            onPressed: onRecord,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, WidgetRef ref, List<PaymentModel> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ID Pembayaran')),
              DataColumn(label: Text('Nominal')),
              DataColumn(label: Text('Metode')),
              DataColumn(label: Text('Referensi Bank')),
              DataColumn(label: Text('Waktu Bayar')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: list.map((p) {
              return DataRow(
                cells: [
                  DataCell(Text(p.id.substring(0, p.id.length > 8 ? 8 : p.id.length), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(
                    Text(
                      AppConstants.formatRupiah(p.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: p.isReversed ? (isDark ? Colors.white38 : const Color(0xFF94A3B8)) : (isDark ? AppColors.success : const Color(0xFF047857)),
                      ),
                    ),
                  ),
                  DataCell(Text(p.paymentMethod)),
                  DataCell(Text(p.referenceNumber.isNotEmpty ? p.referenceNumber : '-')),
                  DataCell(Text(AppConstants.formatDateTime(p.paymentDate))),
                  DataCell(StatusBadge(status: p.isReversed ? 'dibatalkan' : 'lunas')),
                  DataCell(
                    p.isReversed
                        ? Text(
                            'Dibatalkan',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                          )
                        : TextButton(
                            onPressed: () => _handleReversePayment(context, ref, p),
                            child: const Text('Koreksi / Batalkan', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, WidgetRef ref, List<PaymentModel> list) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final p = list[idx];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (p.isReversed ? (isDark ? Colors.white24 : const Color(0xFFE2E8F0)) : (isDark ? AppColors.success : const Color(0xFF10B981))).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    color: p.isReversed ? (isDark ? Colors.white38 : const Color(0xFF94A3B8)) : (isDark ? AppColors.success : const Color(0xFF047857)),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppConstants.formatRupiah(p.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: p.isReversed ? (isDark ? Colors.white38 : const Color(0xFF94A3B8)) : null,
                              decoration: p.isReversed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          StatusBadge(status: p.isReversed ? 'dibatalkan' : 'lunas'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.paymentMethod} • Ref: ${p.referenceNumber.isNotEmpty ? p.referenceNumber : '-'}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                      Text(
                        AppConstants.formatDateTime(p.paymentDate),
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                if (!p.isReversed)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
                    tooltip: 'Batalkan Pembayaran',
                    onPressed: () => _handleReversePayment(context, ref, p),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
