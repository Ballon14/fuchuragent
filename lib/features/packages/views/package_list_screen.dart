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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
          }

          final packages = snapshot.data ?? VpsPackageModel.defaultCatalog;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Konfigurasi Spesifikasi & Skema Diskon Durasi',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
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
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.cyan),
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
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.cyan),
                              ),
                              const SizedBox(height: 12),
                              if (pkg.description.isNotEmpty) ...[
                                Text(pkg.description, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                                const SizedBox(height: 12),
                              ],
                              const Divider(),
                              _buildSpecItem(Icons.memory_rounded, '${pkg.vcpu} vCPU Core'),
                              const SizedBox(height: 8),
                              _buildSpecItem(Icons.storage_rounded, '${pkg.ramGb} GB RAM'),
                              const SizedBox(height: 8),
                              _buildSpecItem(Icons.disc_full_rounded, '${pkg.storageGb} GB HDD Storage'),
                              const Divider(),
                              const Text('Diskon Berlangganan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDiscountChip('1 Bln (8%)', AppConstants.formatRupiah(pkg.calculatePrice(1))),
                                  _buildDiscountChip('3 Bln (10%)', AppConstants.formatRupiah(pkg.calculatePrice(3))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDiscountChip('6 Bln (12%)', AppConstants.formatRupiah(pkg.calculatePrice(6))),
                                  _buildDiscountChip('12 Bln (15%)', AppConstants.formatRupiah(pkg.calculatePrice(12))),
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

  Widget _buildSpecItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDiscountChip(String duration, String price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLightDark,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(duration, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          Text(price, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
