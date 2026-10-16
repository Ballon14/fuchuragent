import 'package:cloud_firestore/cloud_firestore.dart';

class VpsPackageModel {
  final String id;
  final String name;
  final String code;
  final int vcpu;
  final int ramGb;
  final int storageGb;
  final int basePrice; // Integer IDR per bulan
  final bool isActive;
  final String description;
  final Map<int, double> durationDiscounts; // {1: 0.08, 3: 0.10, 6: 0.12, 12: 0.15}

  VpsPackageModel({
    required this.id,
    required this.name,
    required this.code,
    required this.vcpu,
    required this.ramGb,
    required this.storageGb,
    required this.basePrice,
    this.isActive = true,
    this.description = '',
    this.durationDiscounts = const {
      1: 0.08,
      3: 0.10,
      6: 0.12,
      12: 0.15,
    },
  });

  // Calculate total price for given months with discount applied
  int calculatePrice(int months) {
    final discountRate = durationDiscounts[months] ?? 0.0;
    final subtotal = basePrice * months;
    final discount = (subtotal * discountRate).round();
    return subtotal - discount;
  }

  factory VpsPackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final discountsRaw = data['durationDiscounts'] as Map<String, dynamic>? ?? {};
    final discounts = <int, double>{};
    discountsRaw.forEach((key, val) {
      final k = int.tryParse(key);
      if (k != null) {
        discounts[k] = (val as num).toDouble();
      }
    });

    return VpsPackageModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      vcpu: (data['vcpu'] as num?)?.toInt() ?? 1,
      ramGb: (data['ramGb'] as num?)?.toInt() ?? 1,
      storageGb: (data['storageGb'] as num?)?.toInt() ?? 20,
      basePrice: (data['basePrice'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      description: data['description'] as String? ?? '',
      durationDiscounts: discounts.isNotEmpty ? discounts : const {
        1: 0.08,
        3: 0.10,
        6: 0.12,
        12: 0.15,
      },
    );
  }

  Map<String, dynamic> toMap() {
    final discountsMap = <String, double>{};
    durationDiscounts.forEach((k, v) => discountsMap[k.toString()] = v);
    return {
      'name': name,
      'code': code,
      'vcpu': vcpu,
      'ramGb': ramGb,
      'storageGb': storageGb,
      'basePrice': basePrice,
      'isActive': isActive,
      'description': description,
      'durationDiscounts': discountsMap,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Predefined catalog reference packages
  static List<VpsPackageModel> get defaultCatalog => [
    VpsPackageModel(
      id: 'pkg-basic',
      name: 'Basic',
      code: 'basic',
      vcpu: 1,
      ramGb: 1,
      storageGb: 20,
      basePrice: 80000,
      description: '1 vCPU, RAM 1 GB, storage 20 GB HDD',
    ),
    VpsPackageModel(
      id: 'pkg-standard',
      name: 'Standard',
      code: 'standard',
      vcpu: 2,
      ramGb: 2,
      storageGb: 40,
      basePrice: 150000,
      description: '2 vCPU, RAM 2 GB, storage 40 GB HDD',
    ),
    VpsPackageModel(
      id: 'pkg-semipro',
      name: 'Semi Pro',
      code: 'semipro',
      vcpu: 2,
      ramGb: 4,
      storageGb: 80,
      basePrice: 280000,
      description: '2 vCPU, RAM 4 GB, storage 80 GB HDD',
    ),
    VpsPackageModel(
      id: 'pkg-pro',
      name: 'Pro',
      code: 'pro',
      vcpu: 4,
      ramGb: 8,
      storageGb: 120,
      basePrice: 500000,
      description: '4 vCPU, RAM 8 GB, storage 120 GB HDD',
    ),
    VpsPackageModel(
      id: 'pkg-snipeit-basic',
      name: 'Snipe-it Basic',
      code: 'snipe-it-basic',
      vcpu: 1,
      ramGb: 1,
      storageGb: 20,
      basePrice: 77000,
      description: 'Preconfigured Snipe-IT Asset Management',
    ),
  ];
}
