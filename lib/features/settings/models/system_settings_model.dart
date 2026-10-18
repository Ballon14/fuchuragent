class BankAccountModel {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final bool isDefault;

  const BankAccountModel({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.isDefault = false,
  });

  BankAccountModel copyWith({
    String? id,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    bool? isDefault,
  }) {
    return BankAccountModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolder: accountHolder ?? this.accountHolder,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
      'isDefault': isDefault,
    };
  }

  factory BankAccountModel.fromMap(Map<String, dynamic> map) {
    return BankAccountModel(
      id: map['id'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountHolder: map['accountHolder'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }
}

class SystemSettingsModel {
  // 1. Profil Bisnis & Kontak
  final String companyName;
  final String brandName;
  final String supportEmail;
  final String supportPhone;
  final String officeAddress;
  final String website;

  // 2. Rekening Pembayaran
  final List<BankAccountModel> bankAccounts;

  // 3. Konfigurasi Pesan WhatsApp
  final String waGreeting;
  final String waClosing;
  final String waAdminSignature;
  final bool includeBankDetailsInWa;
  final String waDefaultBankTarget; // 'all' or specific bank name

  // 4. Konfigurasi Notifikasi & Otomasi
  final bool enableDueReminders;
  final List<int> reminderDays; // [7, 3, 1, 0]
  final int reminderHour; // 9 = 09:00 WIB
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool autoSyncBackground;
  final bool notifyNewExpenses;
  final bool notifyNewInvoices;

  // 5. Preferensi Tampilan & Format
  final String currencyCode;
  final String currencySymbol;
  final String dateFormat;
  final int defaultItemsPerPage;
  final bool confirmBeforeDelete;
  final bool enableHapticFeedback;

  // 6. Keamanan & Sesi
  final int autoLockMinutes; // 0 = disabled, 5, 15, 30
  final bool requirePasswordOnSensitiveActions;

  // 7. Metadata
  final DateTime? updatedAt;
  final String? updatedBy;

  const SystemSettingsModel({
    required this.companyName,
    required this.brandName,
    required this.supportEmail,
    required this.supportPhone,
    required this.officeAddress,
    required this.website,
    required this.bankAccounts,
    required this.waGreeting,
    required this.waClosing,
    required this.waAdminSignature,
    required this.includeBankDetailsInWa,
    required this.waDefaultBankTarget,
    required this.enableDueReminders,
    required this.reminderDays,
    required this.reminderHour,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.autoSyncBackground,
    required this.notifyNewExpenses,
    required this.notifyNewInvoices,
    required this.currencyCode,
    required this.currencySymbol,
    required this.dateFormat,
    required this.defaultItemsPerPage,
    required this.confirmBeforeDelete,
    required this.enableHapticFeedback,
    required this.autoLockMinutes,
    required this.requirePasswordOnSensitiveActions,
    this.updatedAt,
    this.updatedBy,
  });

  /// Default baseline configuration
  factory SystemSettingsModel.defaultSettings() {
    return SystemSettingsModel(
      companyName: 'FuchurHost Solutions',
      brandName: 'Fuchur Agent',
      supportEmail: 'support@fuchuragent.id',
      supportPhone: '081234567890',
      officeAddress: 'Cyber 2 Tower Lt. 8, Jl. H. R. Rasuna Said, Jakarta Selatan 12950',
      website: 'https://fuchuragent.id',
      bankAccounts: const [
        BankAccountModel(
          id: 'bank-bca',
          bankName: 'Bank BCA',
          accountNumber: '1234567890',
          accountHolder: 'Fuchur Agent',
          isDefault: true,
        ),
        BankAccountModel(
          id: 'bank-mandiri',
          bankName: 'Bank Mandiri',
          accountNumber: '0987654321',
          accountHolder: 'Fuchur Agent',
          isDefault: false,
        ),
        BankAccountModel(
          id: 'bank-bri',
          bankName: 'Bank BRI',
          accountNumber: '556677889900',
          accountHolder: 'Fuchur Agent',
          isDefault: false,
        ),
      ],
      waGreeting: 'Halo Kak *{name}*,',
      waClosing: 'Terima kasih atas kepercayaan Kakak menggunakan layanan Fuchur Agent! 🙏',
      waAdminSignature: 'Fuchur Agent Team',
      includeBankDetailsInWa: true,
      waDefaultBankTarget: 'all',
      enableDueReminders: true,
      reminderDays: const [7, 3, 1, 0],
      reminderHour: 9,
      soundEnabled: true,
      vibrationEnabled: true,
      autoSyncBackground: true,
      notifyNewExpenses: true,
      notifyNewInvoices: true,
      currencyCode: 'IDR',
      currencySymbol: 'Rp',
      dateFormat: 'd MMMM yyyy',
      defaultItemsPerPage: 10,
      confirmBeforeDelete: true,
      enableHapticFeedback: true,
      autoLockMinutes: 0,
      requirePasswordOnSensitiveActions: true,
      updatedAt: DateTime.now(),
      updatedBy: 'System Default',
    );
  }

  SystemSettingsModel copyWith({
    String? companyName,
    String? brandName,
    String? supportEmail,
    String? supportPhone,
    String? officeAddress,
    String? website,
    List<BankAccountModel>? bankAccounts,
    String? waGreeting,
    String? waClosing,
    String? waAdminSignature,
    bool? includeBankDetailsInWa,
    String? waDefaultBankTarget,
    bool? enableDueReminders,
    List<int>? reminderDays,
    int? reminderHour,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? autoSyncBackground,
    bool? notifyNewExpenses,
    bool? notifyNewInvoices,
    String? currencyCode,
    String? currencySymbol,
    String? dateFormat,
    int? defaultItemsPerPage,
    bool? confirmBeforeDelete,
    bool? enableHapticFeedback,
    int? autoLockMinutes,
    bool? requirePasswordOnSensitiveActions,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SystemSettingsModel(
      companyName: companyName ?? this.companyName,
      brandName: brandName ?? this.brandName,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      officeAddress: officeAddress ?? this.officeAddress,
      website: website ?? this.website,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      waGreeting: waGreeting ?? this.waGreeting,
      waClosing: waClosing ?? this.waClosing,
      waAdminSignature: waAdminSignature ?? this.waAdminSignature,
      includeBankDetailsInWa: includeBankDetailsInWa ?? this.includeBankDetailsInWa,
      waDefaultBankTarget: waDefaultBankTarget ?? this.waDefaultBankTarget,
      enableDueReminders: enableDueReminders ?? this.enableDueReminders,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderHour: reminderHour ?? this.reminderHour,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      autoSyncBackground: autoSyncBackground ?? this.autoSyncBackground,
      notifyNewExpenses: notifyNewExpenses ?? this.notifyNewExpenses,
      notifyNewInvoices: notifyNewInvoices ?? this.notifyNewInvoices,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      dateFormat: dateFormat ?? this.dateFormat,
      defaultItemsPerPage: defaultItemsPerPage ?? this.defaultItemsPerPage,
      confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      requirePasswordOnSensitiveActions:
          requirePasswordOnSensitiveActions ?? this.requirePasswordOnSensitiveActions,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'brandName': brandName,
      'supportEmail': supportEmail,
      'supportPhone': supportPhone,
      'officeAddress': officeAddress,
      'website': website,
      'bankAccounts': bankAccounts.map((b) => b.toMap()).toList(),
      'waGreeting': waGreeting,
      'waClosing': waClosing,
      'waAdminSignature': waAdminSignature,
      'includeBankDetailsInWa': includeBankDetailsInWa,
      'waDefaultBankTarget': waDefaultBankTarget,
      'enableDueReminders': enableDueReminders,
      'reminderDays': reminderDays,
      'reminderHour': reminderHour,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'autoSyncBackground': autoSyncBackground,
      'notifyNewExpenses': notifyNewExpenses,
      'notifyNewInvoices': notifyNewInvoices,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'dateFormat': dateFormat,
      'defaultItemsPerPage': defaultItemsPerPage,
      'confirmBeforeDelete': confirmBeforeDelete,
      'enableHapticFeedback': enableHapticFeedback,
      'autoLockMinutes': autoLockMinutes,
      'requirePasswordOnSensitiveActions': requirePasswordOnSensitiveActions,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  factory SystemSettingsModel.fromMap(Map<String, dynamic> map) {
    final defaults = SystemSettingsModel.defaultSettings();

    List<BankAccountModel> banks = defaults.bankAccounts;
    if (map['bankAccounts'] != null && map['bankAccounts'] is List) {
      banks = (map['bankAccounts'] as List)
          .map((item) => BankAccountModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    List<int> reminderDays = defaults.reminderDays;
    if (map['reminderDays'] != null && map['reminderDays'] is List) {
      reminderDays = (map['reminderDays'] as List).map((e) => (e as num).toInt()).toList();
    }

    DateTime? parsedUpdatedAt;
    if (map['updatedAt'] != null) {
      parsedUpdatedAt = DateTime.tryParse(map['updatedAt'].toString());
    }

    return SystemSettingsModel(
      companyName: map['companyName'] ?? defaults.companyName,
      brandName: map['brandName'] ?? defaults.brandName,
      supportEmail: map['supportEmail'] ?? defaults.supportEmail,
      supportPhone: map['supportPhone'] ?? defaults.supportPhone,
      officeAddress: map['officeAddress'] ?? defaults.officeAddress,
      website: map['website'] ?? defaults.website,
      bankAccounts: banks.isNotEmpty ? banks : defaults.bankAccounts,
      waGreeting: map['waGreeting'] ?? defaults.waGreeting,
      waClosing: map['waClosing'] ?? defaults.waClosing,
      waAdminSignature: map['waAdminSignature'] ?? defaults.waAdminSignature,
      includeBankDetailsInWa: map['includeBankDetailsInWa'] ?? defaults.includeBankDetailsInWa,
      waDefaultBankTarget: map['waDefaultBankTarget'] ?? defaults.waDefaultBankTarget,
      enableDueReminders: map['enableDueReminders'] ?? defaults.enableDueReminders,
      reminderDays: reminderDays,
      reminderHour: (map['reminderHour'] as num?)?.toInt() ?? defaults.reminderHour,
      soundEnabled: map['soundEnabled'] ?? defaults.soundEnabled,
      vibrationEnabled: map['vibrationEnabled'] ?? defaults.vibrationEnabled,
      autoSyncBackground: map['autoSyncBackground'] ?? defaults.autoSyncBackground,
      notifyNewExpenses: map['notifyNewExpenses'] ?? defaults.notifyNewExpenses,
      notifyNewInvoices: map['notifyNewInvoices'] ?? defaults.notifyNewInvoices,
      currencyCode: map['currencyCode'] ?? defaults.currencyCode,
      currencySymbol: map['currencySymbol'] ?? defaults.currencySymbol,
      dateFormat: map['dateFormat'] ?? defaults.dateFormat,
      defaultItemsPerPage: (map['defaultItemsPerPage'] as num?)?.toInt() ?? defaults.defaultItemsPerPage,
      confirmBeforeDelete: map['confirmBeforeDelete'] ?? defaults.confirmBeforeDelete,
      enableHapticFeedback: map['enableHapticFeedback'] ?? defaults.enableHapticFeedback,
      autoLockMinutes: (map['autoLockMinutes'] as num?)?.toInt() ?? defaults.autoLockMinutes,
      requirePasswordOnSensitiveActions:
          map['requirePasswordOnSensitiveActions'] ?? defaults.requirePasswordOnSensitiveActions,
      updatedAt: parsedUpdatedAt ?? defaults.updatedAt,
      updatedBy: map['updatedBy'] ?? defaults.updatedBy,
    );
  }
}
