import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../models/package_model.dart';
import 'package:fuchuragent/features/packages/views/package_form_dialog.dart';
import '../../../shared/widgets/app_card.dart';

class PackageListScreen extends ConsumerWidget {
  const PackageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageRepo = ref.watch(packageRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Paket VPS'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Paket'),
            onPressed: () async {
              final newPkg = await PackageFormDialog.show(context);
              if (newPkg != null) {
                await packageRepo.savePackage(newPkg);
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<List<VpsPackageModel>>(
        stream: packageRepo.watchPackages(),
        builder: (context, snapshot) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final packages = (snapshot.data != null && snapshot.data!.isNotEmpty)
              ? List<VpsPackageModel>.from(snapshot.data!)
              : List<VpsPackageModel>.from(VpsPackageModel.defaultCatalog);
          packages.sort((a, b) => a.basePrice.compareTo(b.basePrice));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konfigurasi Spesifikasi & Skema Diskon Durasi',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 1100 ? 3 : (width > 650 ? 2 : 1);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: packages.length,
                      itemBuilder: (context, idx) {
                        final pkg = packages[idx];
                        return AppCard(
                          title: pkg.name,
                          trailing: IconButton(
                            icon: Icon(Icons.edit_outlined, size: 18, color: primaryColor),
                            onPressed: () async {
                              final updated = await PackageFormDialog.show(context, package: pkg);
                              if (updated != null) {
                                await packageRepo.savePackage(updated);
                              }
                            },
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${AppConstants.formatRupiah(pkg.basePrice)} / bln',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                              const SizedBox(height: 12),
                              if (pkg.description.isNotEmpty) ...[
                                Text(
                                  pkg.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              const Divider(),
                              _buildSpecItem(context, Icons.memory_rounded, '${pkg.vcpu} vCPU Core'),
                              const SizedBox(height: 8),
                              _buildSpecItem(context, Icons.storage_rounded, '${pkg.ramGb} GB RAM'),
                              const SizedBox(height: 8),
                              _buildSpecItem(context, Icons.disc_full_rounded, '${pkg.storageGb} GB HDD Storage'),
                              const Divider(),
                              Text(
                                'Diskon Berlangganan:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDiscountChip(context, '1 Bln (8%)', AppConstants.formatRupiah(pkg.calculatePrice(1))),
                                  _buildDiscountChip(context, '3 Bln (10%)', AppConstants.formatRupiah(pkg.calculatePrice(3))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDiscountChip(context, '6 Bln (12%)', AppConstants.formatRupiah(pkg.calculatePrice(6))),
                                  _buildDiscountChip(context, '12 Bln (15%)', AppConstants.formatRupiah(pkg.calculatePrice(12))),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecItem(BuildContext context, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDiscountChip(BuildContext context, String duration, String price) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            duration,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          Text(price, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
