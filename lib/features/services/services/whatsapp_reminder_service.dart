import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../customers/models/customer_model.dart';
import '../models/service_model.dart';
import '../../invoices/models/invoice_model.dart';
import '../../settings/models/system_settings_model.dart';

enum WhatsAppTemplateType {
  expiringSoon,
  expired,
  invoiceReminder,
  custom,
}

class WhatsAppReminderService {
  /// Normalizes phone number to international WhatsApp format (e.g. 628123456789)
  static String normalizePhoneNumber(String rawPhone) {
    String cleaned = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('08')) {
      cleaned = '628${cleaned.substring(2)}';
    } else if (cleaned.startsWith('8')) {
      cleaned = '628${cleaned.substring(1)}';
    } else if (cleaned.startsWith('0062')) {
      cleaned = cleaned.substring(2);
    }
    return cleaned;
  }

  /// Formats bank account list for WhatsApp messages with priority for active payment methods
  static String formatBankAccounts(List<BankAccountModel>? banks, {List<PaymentMethodModel>? paymentMethods}) {
    if (paymentMethods != null && paymentMethods.isNotEmpty) {
      final active = paymentMethods.where((p) => p.isActive && p.accountNumber.trim().isNotEmpty).toList();
      if (active.isNotEmpty) {
        return active
            .map((b) => '• ${b.name}: *${b.accountNumber.trim()}* a.n *${b.accountHolder.trim()}*')
            .join('\n');
      }
    }
    if (banks != null && banks.isNotEmpty) {
      final valid = banks.where((b) => b.accountNumber.trim().isNotEmpty).toList();
      if (valid.isNotEmpty) {
        return valid
            .map((b) => '• ${b.bankName}: *${b.accountNumber.trim()}* a.n *${b.accountHolder.trim()}*')
            .join('\n');
      }
    }
    return '';
  }


  /// Generates template for VPS service that is expiring soon
  static String generateExpiringSoonTemplate({
    required CustomerModel customer,
    required VpsServiceModel service,
    String? adminContact,
    SystemSettingsModel? settings,
  }) {
    final customerName = customer.name.isNotEmpty ? customer.name : 'Pelanggan';
    final domain = service.domain.isNotEmpty ? service.domain : service.serviceName;
    final expiryDate = AppConstants.formatDate(service.endDate);
    final daysLeft = service.daysUntilExpiry;
    final priceStr = AppConstants.formatRupiah(service.price);

    final daysText = daysLeft == 0
        ? 'hari ini'
        : (daysLeft == 1 ? 'besok (1 hari lagi)' : '$daysLeft hari lagi');

    final bankListStr = formatBankAccounts(settings?.bankAccounts, paymentMethods: settings?.paymentMethods);
    final brand = (settings?.brandName.isNotEmpty ?? false) ? settings!.brandName : 'Fuchur Agent';
    final greeting = (settings?.waGreeting.isNotEmpty ?? false)
        ? settings!.waGreeting.replaceAll('{name}', customerName)
        : 'Halo Kak *$customerName*,';
    final closing = (settings?.waClosing.isNotEmpty ?? false)
        ? settings!.waClosing
        : 'Terima kasih atas kepercayaan Kakak menggunakan layanan kami! 🙏';

    final bankSection = bankListStr.isNotEmpty
        ? '\n\n💳 *Rekening Pembayaran Resmi:*\n$bankListStr'
        : '';

    return '''$greeting

Kami dari *$brand* ingin menginformasikan bahwa masa aktif layanan VPS Anda akan segera berakhir:

🌐 *Detail Layanan VPS:*
• Domain / Host: *$domain*
• Paket: *${service.packageName}* (${service.vcpu} vCPU, ${service.ramGb}GB RAM, ${service.storageGb}GB Disk)
• Tanggal Jatuh Tempo: *$expiryDate* ($daysText)
• Biaya Perpanjangan: *$priceStr* / bulan

Untuk menjaga agar website dan sistem Anda tetap online tanpa interupsi, silakan lakukan konfirmasi perpanjangan sewa sebelum tanggal jatuh tempo.$bankSection

Setelah melakukan pembayaran, mohon kirimkan bukti transfer melalui chat WhatsApp ini.

$closing''';
  }

  /// Generates template for VPS service that is already expired
  static String generateExpiredTemplate({
    required CustomerModel customer,
    required VpsServiceModel service,
    String? adminContact,
    SystemSettingsModel? settings,
  }) {
    final customerName = customer.name.isNotEmpty ? customer.name : 'Pelanggan';
    final domain = service.domain.isNotEmpty ? service.domain : service.serviceName;
    final expiryDate = AppConstants.formatDate(service.endDate);
    final priceStr = AppConstants.formatRupiah(service.price);

    final bankListStr = formatBankAccounts(settings?.bankAccounts, paymentMethods: settings?.paymentMethods);
    final brand = (settings?.brandName.isNotEmpty ?? false) ? settings!.brandName : 'Fuchur Agent';
    final greeting = (settings?.waGreeting.isNotEmpty ?? false)
        ? settings!.waGreeting.replaceAll('{name}', customerName)
        : 'Halo Kak *$customerName*,';
    final signature = (settings?.waAdminSignature.isNotEmpty ?? false) ? settings!.waAdminSignature : '$brand Team';

    final bankSection = bankListStr.isNotEmpty
        ? '\n\n💳 *Rekening Pembayaran Transfer:*\n$bankListStr'
        : '';

    return '''$greeting

Kami dari *$brand* menginformasikan bahwa masa aktif layanan VPS Anda telah *berakhir*:

⚠️ *Status Layanan: Kedaluwarsa / Nonaktif*
• Domain / Host: *$domain*
• Paket: *${service.packageName}* (${service.vcpu} vCPU, ${service.ramGb}GB RAM, ${service.storageGb}GB Disk)
• Tanggal Berakhir: *$expiryDate*
• Biaya Perpanjangan: *$priceStr* / bulan

Saat ini server Anda sedang dalam masa tenggang. Agar data server tetap aman dan tidak dinonaktifkan permanen, mohon segera melakukan konfirmasi perpanjangan sewa.$bankSection

Silakan balas pesan ini dan kirimkan bukti transfer jika perpanjangan sudah dilakukan.

Terima kasih atas kerja samanya,
*$signature* 🙏''';
  }

  /// Generates template for specific invoice reminder
  static String generateInvoiceReminderTemplate({
    required CustomerModel customer,
    required InvoiceModel invoice,
    VpsServiceModel? service,
    SystemSettingsModel? settings,
  }) {
    final customerName = customer.name.isNotEmpty ? customer.name : 'Pelanggan';
    final invoiceNumber = invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'INV-TAGIHAN';
    final dueDate = AppConstants.formatDate(invoice.dueDate);
    final totalAmount = AppConstants.formatRupiah(invoice.total);
    final brand = (settings?.brandName.isNotEmpty ?? false) ? settings!.brandName : 'Fuchur Agent';
    final greeting = (settings?.waGreeting.isNotEmpty ?? false)
        ? settings!.waGreeting.replaceAll('{name}', customerName)
        : 'Halo Kak *$customerName*,';
    final bankListStr = formatBankAccounts(settings?.bankAccounts, paymentMethods: settings?.paymentMethods);

    final description = invoice.items.isNotEmpty
        ? invoice.items.first.description
        : (service != null ? 'Perpanjangan VPS ${service.domain}' : 'Layanan VPS $brand');

    final bankSection = bankListStr.isNotEmpty
        ? '\n\n💳 *Rekening Pembayaran Transfer:*\n$bankListStr'
        : '';

    return '''$greeting

Berikut pemberitahuan tagihan invoice dari *$brand*:

📄 *Detail Tagihan Invoice:*
• No. Tagihan: *$invoiceNumber*
• Layanan: *$description*
• Jatuh Tempo: *$dueDate*
• Total Tagihan: *$totalAmount*$bankSection

Mohon konfirmasikan bukti transfer ke WhatsApp ini setelah transaksi berhasil agar status tagihan dapat segera diupdate.

Terima kasih banyak! 🙏''';
  }

  /// Builds WhatsApp wa.me deep-link URI
  static Uri buildWhatsAppUri(String phone, String message) {
    final cleanPhone = normalizePhoneNumber(phone);
    final encodedMsg = Uri.encodeComponent(message);
    return Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');
  }

  /// Copies message text to system clipboard
  static Future<void> copyToClipboard(BuildContext context, String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Template pesan WhatsApp berhasil disalin ke clipboard!')),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Launches WhatsApp via deep-link, and also copies text to clipboard as convenience fallback
  static Future<bool> launchWhatsApp({
    required BuildContext context,
    required String phone,
    required String message,
  }) async {
    final uri = buildWhatsAppUri(phone, message);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback: try launching with platform default
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }

      // Also copy to clipboard for user convenience
      await Clipboard.setData(ClipboardData(text: message));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Membuka WhatsApp & pesan telah disalin ke clipboard.')),
              ],
            ),
            backgroundColor: Color(0xFF0284C7),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return true;
    } catch (e) {
      // If launching fails (e.g. no browser/app), copy to clipboard as graceful fallback
      if (context.mounted) {
        await copyToClipboard(context, message);
      }
      return false;
    }
  }
}
