import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/invoice_model.dart';
import '../../payments/views/record_payment_dialog.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceRepo = ref.watch(invoiceRepositoryProvider);

    return FutureBuilder<InvoiceModel?>(
      future: invoiceRepo.getInvoiceById(invoiceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.cyan)));
        }

        final inv = snapshot.data;
        if (inv == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Tagihan')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Tagihan tidak ditemukan.'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => context.go('/invoices'), child: const Text('Kembali')),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(inv.invoiceNumber),
            actions: [
              if (inv.status != 'cancelled' && !inv.isPaid)
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                  label: const Text('Batalkan Tagihan', style: TextStyle(color: AppColors.danger)),
                  onPressed: () async {
                    final reasonCtrl = TextEditingController();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Batalkan Tagihan'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Apakah Anda yakin ingin membatalkan tagihan ini?'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: reasonCtrl,
                              decoration: const InputDecoration(labelText: 'Alasan Pembatalan *'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Kembali')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Ya, Batalkan'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && reasonCtrl.text.isNotEmpty) {
                      await invoiceRepo.cancelInvoice(inv.id, reasonCtrl.text.trim());
                      ref.invalidate(dashboardStatsProvider);
                    }
                  },
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Card
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.electricBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.electricBlue, size: 36),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(inv.invoiceNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                StatusBadge(status: inv.isOverdue ? 'overdue' : inv.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 20,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Tanggal Terbit: ${AppConstants.formatDate(inv.issuedAt)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'Jatuh Tempo: ${AppConstants.formatDate(inv.dueDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (!inv.isPaid && inv.status != 'cancelled')
                              ElevatedButton.icon(
                                icon: const Icon(Icons.payment_rounded, size: 16),
                                label: const Text('Catat Pembayaran'),
                                onPressed: () async {
                                  final p = await RecordPaymentDialog.show(
                                    context,
                                    preselectedInvoiceId: inv.id,
                                    suggestedAmount: inv.remainingBalance,
                                  );
                                  if (p != null) {
                                    ref.invalidate(dashboardStatsProvider);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Line Items Table
                AppCard(
                  title: 'Rincian Item Tagihan',
                  child: Column(
                    children: [
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(4),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.borderDark : AppColors.borderLight,
                                ),
                              ),
                            ),
                            children: const [
                              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Deskripsi Item', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Harga Satuan', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                          ...inv.items.map((item) {
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(item.description)),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(AppConstants.formatRupiah(item.unitPrice))),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('${item.quantity}')),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(AppConstants.formatRupiah(item.total), textAlign: TextAlign.right)),
                              ],
                            );
                          }),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(context, 'Subtotal', AppConstants.formatRupiah(inv.subtotal)),
                      if (inv.discount > 0)
                        _buildSummaryRow(context, 'Diskon / Potongan', '- ${AppConstants.formatRupiah(inv.discount)}', isNegative: true),
                      const SizedBox(height: 8),
                      _buildSummaryRow(context, 'Total Tagihan', AppConstants.formatRupiah(inv.total), isBold: true),
                      const SizedBox(height: 8),
                      _buildSummaryRow(context, 'Telah Dibayar', AppConstants.formatRupiah(inv.paidAmount), color: AppColors.success),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        context,
                        'Sisa Saldo Belum Dibayar',
                        AppConstants.formatRupiah(inv.remainingBalance),
                        isBold: true,
                        color: inv.remainingBalance > 0 ? AppColors.warning : AppColors.success,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Associated Payments Card
                AppCard(
                  title: 'Riwayat Pembayaran Tagihan Ini',
                  child: StreamBuilder(
                    stream: invoiceRepo.watchInvoicePayments(inv.id),
                    builder: (context, snapshot) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: primaryColor));
                      }
                      final payments = snapshot.data ?? [];
                      if (payments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'Belum ada transaksi pembayaran untuk tagihan ini.',
                              style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final p = payments[idx];
                          return ListTile(
                            leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                            title: Text(AppConstants.formatRupiah(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${p.paymentMethod} • Ref: ${p.referenceNumber.isNotEmpty ? p.referenceNumber : "-"} • ${AppConstants.formatDateTime(p.paymentDate)}'),
                            trailing: StatusBadge(status: p.isReversed ? 'dibatalkan' : 'lunas'),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, {bool isBold = false, bool isNegative = false, Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelTextColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: labelTextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isNegative ? (isDark ? AppColors.danger : const Color(0xFFB91C1C)) : defaultTextColor),
            ),
          ),
        ],
      ),
    );
  }
}
