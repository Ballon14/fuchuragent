import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

class VpsServiceModel {
  final String id;
  final String customerId;
  final String serviceName;
  final String domain;
  final String? packageId;
  final String packageName;
  final int vcpu;
  final int ramGb;
  final int storageGb;
  final int price; // Integer IDR
  final int billingCycleMonths;
  final DateTime? startDate;
  final DateTime? endDate;
  final String _status; // 'active', 'deactive', 'expired', 'pending', 'suspended', 'cancelled'
  final String deploymentType; // 'Publish'
  final String? worker; // 'Iqbal'
  final bool workerPaid;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VpsServiceModel({
    required this.id,
    required this.customerId,
    required this.serviceName,
    required this.domain,
    this.packageId,
    required this.packageName,
    this.vcpu = 1,
    this.ramGb = 1,
    this.storageGb = 20,
    required this.price,
    this.billingCycleMonths = 1,
    this.startDate,
    this.endDate,
    String status = 'active',
    this.deploymentType = 'Publish',
    this.worker,
    this.workerPaid = false,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  }) : _status = status.toLowerCase();

  /// Status layanan VPS:
  /// Jika masa aktif telah kedaluwarsa (endDate < now), status otomatis menjadi 'deactive' (Nonaktif).
  String get status {
    if (isExpired) return 'deactive';
    return _status;
  }

  bool get isActive => !isExpired && (status.toLowerCase() == 'active' || status.toLowerCase() == 'actice');
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  int get daysUntilExpiry {
    if (endDate == null) return 999;
    return endDate!.difference(DateTime.now()).inDays;
  }

  factory VpsServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VpsServiceModel(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      serviceName: data['serviceName'] as String? ?? 'VPS Service',
      domain: data['domain'] as String? ?? '',
      packageId: data['packageId'] as String?,
      packageName: data['packageName'] as String? ?? 'Custom VPS',
      vcpu: (data['vcpu'] as num?)?.toInt() ?? 1,
      ramGb: (data['ramGb'] as num?)?.toInt() ?? 1,
      storageGb: (data['storageGb'] as num?)?.toInt() ?? 20,
      price: (data['price'] as num?)?.toInt() ?? 0,
      billingCycleMonths: (data['billingCycleMonths'] as num?)?.toInt() ?? 1,
      startDate: AppConstants.parseDateTime(data['startDate']),
      endDate: AppConstants.parseDateTime(data['endDate']),
      status: (data['status'] as String? ?? 'active').toLowerCase(),
      deploymentType: data['deploymentType'] as String? ?? 'Publish',
      worker: data['worker'] as String?,
      workerPaid: data['workerPaid'] as bool? ?? false,
      notes: data['notes'] as String? ?? '',
      createdAt: AppConstants.parseDateTime(data['createdAt']),
      updatedAt: AppConstants.parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'serviceName': serviceName,
      'domain': domain,
      'packageId': packageId,
      'packageName': packageName,
      'vcpu': vcpu,
      'ramGb': ramGb,
      'storageGb': storageGb,
      'price': price,
      'billingCycleMonths': billingCycleMonths,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status,
      'deploymentType': deploymentType,
      'worker': worker,
      'workerPaid': workerPaid,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  VpsServiceModel copyWith({
    String? id,
    String? customerId,
    String? serviceName,
    String? domain,
    String? packageId,
    String? packageName,
    int? vcpu,
    int? ramGb,
    int? storageGb,
    int? price,
    int? billingCycleMonths,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? deploymentType,
    String? worker,
    bool? workerPaid,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VpsServiceModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      serviceName: serviceName ?? this.serviceName,
      domain: domain ?? this.domain,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      vcpu: vcpu ?? this.vcpu,
      ramGb: ramGb ?? this.ramGb,
      storageGb: storageGb ?? this.storageGb,
      price: price ?? this.price,
      billingCycleMonths: billingCycleMonths ?? this.billingCycleMonths,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      deploymentType: deploymentType ?? this.deploymentType,
      worker: worker ?? this.worker,
      workerPaid: workerPaid ?? this.workerPaid,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
