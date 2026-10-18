import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_providers.dart';
import '../../customers/models/customer_model.dart';
import '../models/service_model.dart';
import '../../invoices/models/invoice_model.dart';
import '../services/whatsapp_reminder_service.dart';

class WhatsAppReminderDialog extends ConsumerStatefulWidget {
  final VpsServiceModel service;
  final CustomerModel? customer;
  final InvoiceModel? invoice;

  const WhatsAppReminderDialog({
    super.key,
    required this.service,
    this.customer,
    this.invoice,
  });

  static Future<void> show(
    BuildContext context, {
    required VpsServiceModel service,
    CustomerModel? customer,
    InvoiceModel? invoice,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => WhatsAppReminderDialog(
        service: service,
        customer: customer,
        invoice: invoice,
      ),
    );
  }

  @override
  ConsumerState<WhatsAppReminderDialog> createState() => _WhatsAppReminderDialogState();
}

class _WhatsAppReminderDialogState extends ConsumerState<WhatsAppReminderDialog> {
  late TextEditingController _messageCtrl;
  late TextEditingController _phoneCtrl;
  WhatsAppTemplateType _selectedType = WhatsAppTemplateType.expiringSoon;
  CustomerModel? _customer;
  bool _isLoadingCustomer = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _messageCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: _customer?.phone ?? '');

    // Default template type based on expiration status
    if (widget.service.isExpired) {
      _selectedType = WhatsAppTemplateType.expired;
    } else {
      _selectedType = WhatsAppTemplateType.expiringSoon;
    }

    if (_customer == null) {
      _loadCustomer();
    } else {
      _updateTemplateText();
    }
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoadingCustomer = true);
    try {
      final cust = await ref.read(customerRepositoryProvider).getCustomerById(widget.service.customerId);
      if (mounted) {
        setState(() {
          _customer = cust;
          _phoneCtrl.text = cust?.phone ?? '';
          _isLoadingCustomer = false;
        });
        _updateTemplateText();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCustomer = false);
        _updateTemplateText();
      }
    }
  }

  void _updateTemplateText() {
    final cust = _customer ??
        CustomerModel(
          id: widget.service.customerId,
          name: 'Pelanggan',
          phone: _phoneCtrl.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final settings = ref.read(systemSettingsProvider).asData?.value;

    String template = '';
    switch (_selectedType) {
      case WhatsAppTemplateType.expiringSoon:
        template = WhatsAppReminderService.generateExpiringSoonTemplate(
          customer: cust,
          service: widget.service,
          settings: settings,
        );
        break;
      case WhatsAppTemplateType.expired:
        template = WhatsAppReminderService.generateExpiredTemplate(
          customer: cust,
          service: widget.service,
          settings: settings,
        );
        break;
      case WhatsAppTemplateType.invoiceReminder:
        if (widget.invoice != null) {
          template = WhatsAppReminderService.generateInvoiceReminderTemplate(
            customer: cust,
            invoice: widget.invoice!,
            service: widget.service,
            settings: settings,
          );
        } else {
          // Synthetic invoice template based on service price
          final dummyInv = InvoiceModel(
            id: '',
            invoiceNumber: 'INV-${widget.service.domain.replaceAll(".", "").toUpperCase()}',
            customerId: cust.id,
            serviceId: widget.service.id,
            items: [
              InvoiceItem(
                description: 'Perpanjangan Layanan VPS - ${widget.service.domain}',
                unitPrice: widget.service.price,
                quantity: 1,
                total: widget.service.price,
              )
            ],
            subtotal: widget.service.price,
            discount: 0,
            total: widget.service.price,
            paidAmount: 0,
            status: 'unpaid',
            issuedAt: DateTime.now(),
            dueDate: widget.service.endDate,
          );
          template = WhatsAppReminderService.generateInvoiceReminderTemplate(
            customer: cust,
            invoice: dummyInv,
            service: widget.service,
            settings: settings,
          );
        }
        break;
      case WhatsAppTemplateType.custom:
        // Keep whatever text is currently in controller or start with basic greeting
        if (_messageCtrl.text.isEmpty) {
          template = 'Halo Kak *${cust.name}*,\n\n';
        } else {
          template = _messageCtrl.text;
        }
        break;
    }

    setState(() {
      _messageCtrl.text = template;
    });
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onTemplateTypeChanged(WhatsAppTemplateType type) {
    if (_selectedType == type) return;
    _selectedType = type;
    _updateTemplateText();
  }

  Future<void> _handleCopy() async {
    await WhatsAppReminderService.copyToClipboard(context, _messageCtrl.text);
  }

  Future<void> _handleDirectWhatsApp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor WhatsApp pelanggan belum diisi.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    await WhatsAppReminderService.launchWhatsApp(
      context: context,
      phone: phone,
      message: _messageCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.cyan : const Color(0xFF0284C7);
    const waGreen = Color(0xFF25D366);
    final isMobile = MediaQuery.of(context).size.width < 640;

    final customerName = _isLoadingCustomer
        ? 'Memuat data pelanggan...'
        : (_customer?.name ?? 'Pelanggan');
    final destinationPhone = _phoneCtrl.text.trim();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: waGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_rounded,
              color: waGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Template Pesan WhatsApp',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Kirim pengingat perpanjangan masa aktif VPS ke pelanggan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer & VPS Target Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceLightDark : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      child: Text(
                        customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.service.isExpired
                                      ? AppColors.danger.withValues(alpha: 0.15)
                                      : AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.service.isExpired
                                      ? 'Kedaluwarsa'
                                      : 'Sisa ${widget.service.daysUntilExpiry} hari',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: widget.service.isExpired ? AppColors.danger : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, size: 13, color: waGreen),
                              const SizedBox(width: 4),
                              Text(
                                destinationPhone.isNotEmpty ? destinationPhone : 'Nomor HP belum ada',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: destinationPhone.isNotEmpty
                                      ? (isDark ? Colors.white70 : const Color(0xFF334155))
                                      : AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '• ${widget.service.domain}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Template Type Selector (Chips / Segments)
              Text(
                'Pilih Jenis Pesan Template:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTemplateChip(
                      type: WhatsAppTemplateType.expiringSoon,
                      label: 'Hampir Berakhir (H-7 s.d H-1)',
                      icon: Icons.timer_outlined,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildTemplateChip(
                      type: WhatsAppTemplateType.expired,
                      label: 'Sudah Berakhir (Expired)',
                      icon: Icons.warning_amber_rounded,
                      primaryColor: AppColors.danger,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildTemplateChip(
                      type: WhatsAppTemplateType.invoiceReminder,
                      label: 'Tagihan Invoice',
                      icon: Icons.receipt_long_rounded,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildTemplateChip(
                      type: WhatsAppTemplateType.custom,
                      label: 'Kustom',
                      icon: Icons.edit_note_rounded,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Message Preview & Editor
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Isi Pesan WhatsApp (Dapat Diedit):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Reset Template', style: TextStyle(fontSize: 11)),
                    onPressed: _updateTemplateText,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              TextFormField(
                controller: _messageCtrl,
                maxLines: isMobile ? 8 : 10,
                style: const TextStyle(fontSize: 12.5, height: 1.45),
                decoration: InputDecoration(
                  hintText: 'Ketik pesan WhatsApp...',
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceLightDark : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Helpful tips
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Teks dapat langsung disalin ke WhatsApp web atau dikirim otomatis via tombol di bawah.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Salin Pesan'),
          onPressed: _handleCopy,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: waGreen,
            foregroundColor: Colors.white,
            elevation: 1,
          ),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Buka WhatsApp'),
          onPressed: _handleDirectWhatsApp,
        ),
      ],
    );
  }

  Widget _buildTemplateChip({
    required WhatsAppTemplateType type,
    required String label,
    required IconData icon,
    required Color primaryColor,
    required bool isDark,
  }) {
    final isSelected = _selectedType == type;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white60 : const Color(0xFF64748B)),
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: primaryColor,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => _onTemplateTypeChanged(type),
    );
  }
}
