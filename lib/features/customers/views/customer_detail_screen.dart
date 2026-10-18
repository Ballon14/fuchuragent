import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/customer_model.dart';
import '../../services/models/service_model.dart';
import '../../invoices/models/invoice_model.dart';
import '../../payments/models/payment_model.dart';
import 'customer_form_dialog.dart';
import '../../services/views/service_form_dialog.dart';
import '../../invoices/views/invoice_form_dialog.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleEdit(CustomerModel customer) async {
    final updated = await CustomerFormDialog.show(context, customer: customer);
    if (updated != null) {
      await ref.read(customerRepositoryProvider).updateCustomer(updated);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data pelanggan berhasil diperbarui.')),
        );
      }
    }
  }

  Future<void> _handleArchive(CustomerModel customer) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Arsipkan Pelanggan',
      message: 'Apakah Anda yakin ingin mengarsipkan pelanggan "${customer.name}"?',
      confirmText: 'Arsipkan',
      isDestructive: true,
    );
    if (confirmed) {
      await ref.read(customerRepositoryProvider).archiveCustomer(customer.id);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pelanggan berhasil diarsipkan.')),
        );
      }
    }
  }

  Future<void> _handleDelete(CustomerModel customer) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Hapus Pelanggan Permanen',
      message: 'Penghapusan permanen hanya diizinkan jika pelanggan tidak memiliki riwayat layanan atau tagihan.',
      confirmText: 'Hapus Permanen',
      isDestructive: true,
    );
    if (confirmed) {
      try {
        await ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
        ref.invalidate(dashboardStatsProvider);
        if (mounted) {
          context.go('/customers');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pelanggan berhasil dihapus.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerRepo = ref.watch(customerRepositoryProvider);

    return FutureBuilder<CustomerModel?>(
      future: customerRepo.getCustomerById(widget.customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.cyan)));
        }

        final customer = snapshot.data;
        if (customer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Pelanggan')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pelanggan tidak ditemukan.'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => context.go('/customers'), child: const Text('Kembali')),
                ],
              ),
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
        final mutedIconColor = isDark ? Colors.white60 : const Color(0xFF64748B);

        return Scaffold(
            appBar: AppBar(
              title: Text(customer.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Pelanggan',
                  onPressed: () => _handleEdit(customer),
                ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'Arsipkan',
                  onPressed: () => _handleArchive(customer),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  tooltip: 'Hapus',
                  onPressed: () => _handleDelete(customer),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Overview Card
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                          child: Text(
                            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                  StatusBadge(status: customer.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 20,
                                runSpacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone_rounded, size: 16, color: mutedIconColor),
                                      const SizedBox(width: 6),
                                      Text(customer.phone, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                  if (customer.sourceId.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.badge_rounded, size: 16, color: mutedIconColor),
                                        const SizedBox(width: 6),
                                        Text('ID Pelanggan: ${customer.sourceId}', style: const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  if (customer.email != null && customer.email!.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.email_rounded, size: 16, color: mutedIconColor),
                                        const SizedBox(width: 6),
                                        Text(customer.email!, style: const TextStyle(fontSize: 13)),
                                      ],
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 16, color: mutedIconColor),
                                      const SizedBox(width: 6),
                                      Text('Terdaftar: ${AppConstants.formatShortDate(customer.createdAt)}', style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                              if (customer.notes.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                    ),
                                  ),
                                  child: Text(
                                    'Catatan: ${customer.notes}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tabs: VPS Services, Invoices, Payments
                  TabBar(
                    controller: _tabController,
                    indicatorColor: primaryColor,
                    labelColor: primaryColor,
                    unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                    tabs: const [
                      Tab(text: 'Layanan VPS', icon: Icon(Icons.dns_rounded, size: 18)),
                      Tab(text: 'Riwayat Tagihan', icon: Icon(Icons.receipt_long_rounded, size: 18)),
                      Tab(text: 'Riwayat Pembayaran', icon: Icon(Icons.payments_rounded, size: 18)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 500,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildServicesTab(customer),
                        _buildInvoicesTab(customer),
                        _buildPaymentsTab(customer),
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

  Widget _buildServicesTab(CustomerModel customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return StreamBuilder<List<VpsServiceModel>>(
      stream: ref.watch(customerRepositoryProvider).watchCustomerServices(customer.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Gagal memuat layanan: ${snapshot.error}',
                    style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final services = snapshot.data ?? [];

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ${services.length} Layanan VPS', style: const TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah VPS'),
                  onPressed: () async {
                    final svc = await ServiceFormDialog.show(context, preselectedCustomerId: customer.id);
                    if (svc != null) {
                      await ref.read(serviceRepositoryProvider).addService(svc);
                      ref.invalidate(dashboardStatsProvider);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: services.isEmpty
                  ? Center(
                      child: Text(
                        'Pelanggan ini belum memiliki layanan VPS.',
                        style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: services.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final s = services[idx];
                        return Card(
                          child: ListTile(
                            leading: Icon(Icons.dns_rounded, color: primaryColor),
                            title: Text(s.domain, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${s.packageName} • Rp${s.price}/bln • Exp: ${AppConstants.formatShortDate(s.endDate)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: s.status),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  onPressed: () => context.go('/services/${s.id}'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInvoicesTab(CustomerModel customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return StreamBuilder<List<InvoiceModel>>(
      stream: ref.watch(customerRepositoryProvider).watchCustomerInvoices(customer.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Gagal memuat tagihan: ${snapshot.error}',
                    style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final invoices = snapshot.data ?? [];

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ${invoices.length} Tagihan', style: const TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Buat Tagihan Baru'),
                  onPressed: () async {
                    final inv = await InvoiceFormDialog.show(context, preselectedCustomerId: customer.id);
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
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: invoices.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat tagihan.',
                        style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: invoices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final inv = invoices[idx];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_rounded, color: AppColors.electricBlue),
                            title: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Total: ${AppConstants.formatRupiah(inv.total)} • Dibayar: ${AppConstants.formatRupiah(inv.paidAmount)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: inv.status),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  onPressed: () => context.go('/invoices/${inv.id}'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentsTab(CustomerModel customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

    return StreamBuilder<List<PaymentModel>>(
      stream: ref.watch(customerRepositoryProvider).watchCustomerPayments(customer.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Gagal memuat pembayaran: ${snapshot.error}',
                    style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final payments = snapshot.data ?? [];

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ${payments.length} Pembayaran', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: payments.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat pembayaran.',
                        style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: payments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final p = payments[idx];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.payment_rounded, color: AppColors.success),
                            title: Text(AppConstants.formatRupiah(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${p.paymentMethod} • ${AppConstants.formatDateTime(p.paymentDate)}'),
                            trailing: StatusBadge(status: p.isReversed ? 'dibatalkan' : 'lunas'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
