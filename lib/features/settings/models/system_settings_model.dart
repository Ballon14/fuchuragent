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
      bankName: map['bankName'] ?? map['name'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountHolder: map['accountHolder'] ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }
}

class PaymentMethodModel {
  final String id;
  final String name; // e.g. "Bank BCA", "Bank Mandiri", "QRIS", "Tunai (Cash)"
  final String accountNumber; // Rekening / ID / Merchant No (dynamic, dapat dirubah-rubah)
  final String accountHolder; // Atas Nama Pemilik Rekening
  final String type; // 'bank_transfer', 'qris', 'ewallet', 'cash', 'other'
  final String notes; // Catatan atau petunjuk transfer
  final bool isActive;
  final bool isDefault;

  const PaymentMethodModel({
    required this.id,
    required this.name,
    required this.accountNumber,
    required this.accountHolder,
    this.type = 'bank_transfer',
    this.notes = '',
    this.isActive = true,
    this.isDefault = false,
  });

  /// Formatted label for display in dropdowns & invoice screens
  String get formattedDisplay {
    if (accountNumber.isNotEmpty && accountHolder.isNotEmpty) {
      return '$name - $accountNumber (a.n $accountHolder)';
    } else if (accountNumber.isNotEmpty) {
      return '$name ($accountNumber)';
    }
    return name;
  }

  BankAccountModel toBankAccount() {
    return BankAccountModel(
      id: id,
      bankName: name,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      isDefault: isDefault,
    );
  }

  PaymentMethodModel copyWith({
    String? id,
    String? name,
    String? accountNumber,
    String? accountHolder,
    String? type,
    String? notes,
    bool? isActive,
    bool? isDefault,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolder: accountHolder ?? this.accountHolder,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
      'type': type,
      'notes': notes,
      'isActive': isActive,
      'isDefault': isDefault,
    };
  }

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      id: map['id'] ?? '',
      name: map['name'] ?? map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountHolder: map['accountHolder'] ?? '',
      type: map['type'] ?? 'bank_transfer',
      notes: map['notes'] ?? '',
      isActive: map['isActive'] ?? true,
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

  // 2. Metode Pembayaran & Rekening Dinamis
  final List<PaymentMethodModel> paymentMethods;
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
  final int autoLockMinutes;
  final bool requirePasswordOnSensitiveActions;

  // 7. Integrasi Backup Google Spreadsheet
  final String spreadsheetBackupUrl;
  final String spreadsheetWebhookUrl;

  // 8. Metadata
  final DateTime? updatedAt;
  final String? updatedBy;

  const SystemSettingsModel({
    required this.companyName,
    required this.brandName,
    required this.supportEmail,
    required this.supportPhone,
    required this.officeAddress,
    required this.website,
    required this.paymentMethods,
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
    this.spreadsheetBackupUrl = 'https://docs.google.com/spreadsheets/d/1Rdcg6rgp4K7qBO328qeqHfzpaaYZjcRgvsI_OQGjLkE/edit?usp=sharing',
    this.spreadsheetWebhookUrl = '',
    this.updatedAt,
    this.updatedBy,
  });

  /// Default baseline configuration
  factory SystemSettingsModel.defaultSettings() {
    const defaultMethods = [
      PaymentMethodModel(
        id: 'pm-jago',
        name: 'Bank Jago',
        accountNumber: '1078-5455-7360',
        accountHolder: 'MUHAMMAD IQBAL FATCHURROHMAN',
        type: 'bank_transfer',
        notes: 'Transfer via Aplikasi Bank Jago, ATM, atau Mobile Banking',
        isActive: true,
        isDefault: true,
      ),
    ];


    return SystemSettingsModel(
      companyName: 'FuchurHost Solutions',
      brandName: 'Fuchur Agent',
      supportEmail: 'support@fuchuragent.id',
      supportPhone: '081234567890',
      officeAddress: 'Cyber 2 Tower Lt. 8, Jl. H. R. Rasuna Said, Jakarta Selatan 12950',
      website: 'https://fuchuragent.id',
      paymentMethods: defaultMethods,
      bankAccounts: defaultMethods.map((m) => m.toBankAccount()).toList(),
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
      spreadsheetBackupUrl: 'https://docs.google.com/spreadsheets/d/1Rdcg6rgp4K7qBO328qeqHfzpaaYZjcRgvsI_OQGjLkE/edit?usp=sharing',
      spreadsheetWebhookUrl: '',
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
    List<PaymentMethodModel>? paymentMethods,
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
    String? spreadsheetBackupUrl,
    String? spreadsheetWebhookUrl,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    final updatedMethods = paymentMethods ?? this.paymentMethods;
    final updatedBanks = bankAccounts ?? updatedMethods.map((m) => m.toBankAccount()).toList();

    return SystemSettingsModel(
      companyName: companyName ?? this.companyName,
      brandName: brandName ?? this.brandName,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      officeAddress: officeAddress ?? this.officeAddress,
      website: website ?? this.website,
      paymentMethods: updatedMethods,
      bankAccounts: updatedBanks,
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
      spreadsheetBackupUrl: spreadsheetBackupUrl ?? this.spreadsheetBackupUrl,
      spreadsheetWebhookUrl: spreadsheetWebhookUrl ?? this.spreadsheetWebhookUrl,
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
      'paymentMethods': paymentMethods.map((p) => p.toMap()).toList(),
      'bankAccounts': paymentMethods.map((p) => p.toBankAccount().toMap()).toList(),
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
      'spreadsheetBackupUrl': spreadsheetBackupUrl,
      'spreadsheetWebhookUrl': spreadsheetWebhookUrl,
      'updatedAt': updatedAt?.toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  factory SystemSettingsModel.fromMap(Map<String, dynamic> map) {
    final defaults = SystemSettingsModel.defaultSettings();

    List<PaymentMethodModel> methods = [];
    if (map['paymentMethods'] != null && map['paymentMethods'] is List) {
      methods = (map['paymentMethods'] as List)
          .map((item) => PaymentMethodModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } else if (map['bankAccounts'] != null && map['bankAccounts'] is List) {
      methods = (map['bankAccounts'] as List)
          .map((item) => PaymentMethodModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Filter out legacy dummy sample accounts
    methods.removeWhere((m) =>
        m.accountNumber == '1234567890' ||
        m.accountNumber == '0987654321' ||
        m.accountNumber == '556677889900');

    if (methods.isEmpty) {
      methods = defaults.paymentMethods;
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
      paymentMethods: methods.isNotEmpty ? methods : defaults.paymentMethods,
      bankAccounts: methods.map((m) => m.toBankAccount()).toList(),
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
      spreadsheetBackupUrl: map['spreadsheetBackupUrl'] ?? defaults.spreadsheetBackupUrl,
      spreadsheetWebhookUrl: map['spreadsheetWebhookUrl'] ?? defaults.spreadsheetWebhookUrl,
      updatedAt: parsedUpdatedAt ?? defaults.updatedAt,
      updatedBy: map['updatedBy'] ?? defaults.updatedBy,
    );
  }
}
