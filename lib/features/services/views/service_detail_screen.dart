import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/service_model.dart';
import 'service_form_dialog.dart';
import '../../renewals/views/renew_action_dialog.dart';
import '../../invoices/views/invoice_form_dialog.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';

class ServiceDetailScreen extends ConsumerWidget {
  final String serviceId;

  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceRepo = ref.watch(serviceRepositoryProvider);

    return FutureBuilder<VpsServiceModel?>(
      future: serviceRepo.getServiceById(serviceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.cyan)));
        }

        final svc = snapshot.data;
        if (svc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Layanan VPS')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Layanan VPS tidak ditemukan.'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => context.go('/services'), child: const Text('Kembali')),
                ],
              ),
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

        return Scaffold(
          appBar: AppBar(
            title: Text(svc.domain),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit Layanan',
                onPressed: () async {
                  final updated = await ServiceFormDialog.show(context, service: svc);
                  if (updated != null) {
                    await ref.read(serviceRepositoryProvider).updateService(updated);
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
                // Top Header Card
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.dns_rounded, color: primaryColor, size: 36),
                      ),
                      const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  svc.domain,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ),
                              StatusBadge(status: svc.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${svc.packageName} • ${svc.deploymentType}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.autorenew_rounded, size: 16),
                                  label: const Text('Perpanjang Layanan'),
                                  onPressed: () async {
                                    await RenewActionDialog.show(context, service: svc);
                                  },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                  label: const Text('Buat Tagihan Baru'),
                                  onPressed: () async {
                                    final inv = await InvoiceFormDialog.show(
                                      context,
                                      preselectedCustomerId: svc.customerId,
                                      preselectedServiceId: svc.id,
                                      suggestedAmount: svc.price,
                                    );
                                    if (inv != null) {
                                      await ref.read(invoiceRepositoryProvider).createInvoice(
                                            customerId: inv.customerId,
                                            serviceId: inv.serviceId,
                                            items: inv.items,
                                            discount: inv.discount,
                                            dueDate: inv.dueDate,
                                            notes: inv.notes,
                                          );
                                      ref.invalidate(dashboardStatsProvider);
                                    }
                                  },
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.person_rounded, size: 16),
                                  label: const Text('Lihat Pelanggan'),
                                  onPressed: () => context.go('/customers/${svc.customerId}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Specifications & Financial details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppCard(
                        title: 'Spesifikasi Instance',
                        child: Column(
                          children: [
                            _buildInfoRow(context, 'Processor', '${svc.vcpu} vCPU Core'),
                            const Divider(height: 16),
                            _buildInfoRow(context, 'Memory RAM', '${svc.ramGb} GB RAM'),
                            const Divider(height: 16),
                            _buildInfoRow(context, 'Storage Disk', '${svc.storageGb} GB HDD/NVMe'),
                            const Divider(height: 16),
                            _buildInfoRow(context, 'Tipe Deployment', svc.deploymentType),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: AppCard(
                        title: 'Masa Aktif & Biaya',
                        child: Column(
                          children: [
                            _buildInfoRow(context, 'Harga Sewa', '${AppConstants.formatRupiah(svc.price)} / bln'),
                            const Divider(height: 16),
                            _buildInfoRow(context, 'Mulai Aktif', AppConstants.formatDate(svc.startDate)),
                            const Divider(height: 16),
                            _buildInfoRow(context, 'Jatuh Tempo', AppConstants.formatDate(svc.endDate)),
                            const Divider(height: 16),
                            _buildInfoRow(context, 'Sisa Waktu', svc.isExpired ? 'Telah Berakhir' : '${svc.daysUntilExpiry} Hari',
                                color: svc.isExpired ? const Color(0xFFEF4444) : null),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Worker info & internal notes
                AppCard(
                  title: 'Informasi Penanggung Jawab & Catatan',
                  child: Column(
                    children: [
                      _buildInfoRow(context, 'Worker Staf', svc.worker ?? 'Belum ditentukan'),
                      const Divider(height: 16),
                      _buildInfoRow(
                        context,
                        'Status Honor Worker',
                        svc.workerPaid ? 'LUNAS' : 'BELUM DIBAYAR',
                        color: svc.workerPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      if (svc.notes.isNotEmpty) ...[
                        const Divider(height: 16),
                        _buildInfoRow(context, 'Catatan Teknis', svc.notes),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}
