# 🤖 AGENT.md — Panduan & Standar Operasional Agent (FuchurAgent)

> **Dokumen Panduan Resmi AI Coding Assistant & Developer**  
> *Sistem Operasional ERP & Pengelolaan Infrastruktur Cloud Hosting FuchurAgent.*  
> Versi: 1.0.0 • Terakhir Diperbarui: 2026-10-30

---

## 🎯 1. Prinsip Utama & Filosofi Proyek

Semua AI Agent dan developer yang berkontribusi pada repositori ini **WAJIB** mematuhi prinsip inti:

1. **ZERO HARDCODED DATA (100% Firebase Firestore Driven)**:
   - Dilarang keras menaruh data dummy, mock list statis, atau fallback hardcoded untuk entitas bisnis (pelanggan, layanan VPS, tagihan, kas pembayaran, pengeluaran, paket, bank/rekening, log, notifikasi).
   - Seluruh data operasional, master data, serta konfigurasi profil bisnis harus berasal langsung dari Firebase (`cloud_firestore`, `firebase_auth`).
2. **Reaktif & Real-Time First**:
   - Menggunakan `StreamBuilder` atau Riverpod `StreamProvider` untuk memantau data secara real-time.
   - Perubahan data di Firestore harus langsung terefleksi pada antarmuka tanpa perlu restart aplikasi.
3. **Integritas Transaksi Finansial**:
   - Pencatatan pembayaran, pembuatan faktur, dan perpanjangan masa aktif wajib menggunakan transaksi atomik (`runTransaction`) atau Cloud Functions callable guna mencegah duplikasi atau ketidakkonsistenan saldo.
4. **Konsistensi Penamaan Koleksi**:
   - Gunakan nama koleksi resmi Firestore yang telah distandarisasi (lihat tabel di Bagian 3).
5. **Kebersihan Kode & Linter**:
   - Kode yang ditambahkan/diubah wajib lolos `flutter analyze` dengan status `No issues found!`.
6. **Otomatis Langsung Push ke GitHub**:
   - Setiap kali AI Agent atau developer selesai menyelesaikan tugas/task (dan telah memverifikasi `flutter analyze` bersih), **WAJIB** langsung melakukan commit yang jelas dan melakukan `git push origin main` ke repositori GitHub agar seluruh progres selalu sinkron dan aman.

---

## 🛠 2. Teknologi & Arsitektur Sistem

- **Framework**: Flutter 3.x / Dart 3.x (Multi-platform: Android, Windows, Web, iOS).
- **State Management**: [Flutter Riverpod 3.x](https://riverpod.dev) (`NotifierProvider`, `StreamProvider`, `FutureProvider`).
- **Backend & Database**: Firebase Firestore (`cloud_firestore: ^7.0.0`) & Firebase Auth (`firebase_auth: ^7.0.0`).
- **Routing**: [GoRouter 17.x](https://pub.dev/packages/go_router) menggunakan pola `ShellRoute` (Sidebar Desktop & Drawer/Appbar Mobile).
- **Notifikasi**: `flutter_local_notifications` dengan 3 Saluran OS Android.
- **Visualisasi Data**: `fl_chart` untuk diagram interaktif donat & grafik tren keuangan.
- **Ekspor/Impor**: `package:csv` (`csv.encode` / `csv.decode`).
- **Persistensi Lokal**: `shared_preferences` khusus untuk preferensi tema antarmuka (Dark/Light Mode).

---

## 🗄 3. Peta Koleksi Firestore Resmi (Single Source of Truth)

AI Agent **dilarang membuat nama koleksi alternatif**. Gunakan nama koleksi resmi berikut:

| Koleksi Firestore | Model Dart | Penanggung Jawab Repositori | Keterangan |
| :--- | :--- | :--- | :--- |
| `users` | `UserModel` | `AuthRepository` | Data pengguna, nama, email, phone, dan role (`superadmin`, `admin`, `staff`). |
| `customers` | `CustomerModel` | `CustomerRepository` | Master pelanggan. Status dihitung dinamis dari layanan VPS. |
| `vps_services` | `VpsServiceModel` | `ServiceRepository` | Layanan VPS aktif/kedaluwarsa. **JANGAN gunakan nama `services`!** |
| `vps_packages` | `VpsPackageModel` | `PackageRepository` | Katalog spesifikasi server (vCPU, RAM, Disk, Harga, Diskon). |
| `invoices` | `InvoiceModel` | `InvoiceRepository` | Faktur tagihan (`unpaid`, `partial`, `paid`, `cancelled`). |
| `payments` | `PaymentModel` | `PaymentRepository` | Transaksi penerimaan kas masuk yang terhubung ke tagihan. |
| `expenses` | `ExpenseModel` | `ExpenseRepository` | Buku kas keluar operasional format nomor `EXP-XXX`. |
| `service_renewals` | `ServiceRenewalModel` | `RenewalRepository` | Riwayat log perpanjangan durasi VPS. |
| `activity_logs` | `ActivityLogModel` | `AuditRepository` | Audit trail sistem. **JANGAN gunakan nama `audit_logs`!** |
| `notifications` | `AppNotificationModel` | `NotificationRepository` | Notifikasi sistem & background alerts. |
| `settings` | `SystemSettingsModel` | `SettingsRepository` | Dokumen tunggal `system_config` (profil bisnis, rekening dinamis, WA template). |
| `app_settings` | Dokumen atomic | `InvoiceRepository` | Dokumen `invoice_counter` untuk nomor faktur berurutan `INV-YYYYMM-XXXX`. |

---

## 📐 4. Struktur Direktori Proyek

Arsitektur menggunakan pendekatan **Feature-First**:

```text
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart          # Formatter mata uang Rupiah, parser tanggal defensif, palet warna
│   ├── providers/
│   │   └── app_providers.dart          # Riverpod Provider Master (Auth, Settings, Repositories, Theme)
│   ├── router/
│   │   └── app_router.dart             # Konfigurasi GoRouter rute terpusat dengan Auth Guard
│   └── theme/
│       └── app_theme.dart              # Skema tema gelap (Slate 900) & tema terang
├── features/
│   ├── audit/                          # Audit Log & Riwayat Aktivitas Sistem
│   ├── auth/                           # Login, Bootstrap Admin, Profil, & User Management
│   ├── customers/                      # Manajemen Pelanggan (CRUD, Generator ID CUS-XXX, Status Dinamis)
│   ├── dashboard/                      # Ringkasan KPI, Donut Chart Interaktif, Follow-up
│   ├── expenses/                       # Kas Keluar, Generator EXP-XXX, Kategori Biaya
│   ├── finance/                        # Arus Kas Bersih, Piutang (Debt Aging), Ekspor CSV
│   ├── imports/                        # Halaman redirect / penanganan spreadsheet
│   ├── invoices/                       # Penagihan, Generator INV-YYYYMM-XXXX, Pembatalan Tagihan
│   ├── notifications/                  # Layanan Notifikasi Lokal OS Android & Polling Background
│   ├── packages/                       # Katalog Spesifikasi VPS & Skema Diskon Durasi
│   ├── payments/                       # Rekonsiliasi Kas Masuk, Pembatalan (Reverse Payment)
│   ├── profile/                        # Informasi Akun Admin & Ganti Password
│   ├── renewals/                       # Monitoring H-7 s.d Kedaluwarsa & Dialog Perpanjangan
│   ├── reports/                        # Rekapitulasi Operasional & Ekspor CSV Langsung dari Firestore
│   ├── services/                       # Manajemen VPS Hosting, Detail Server, & WA Reminder
│   └── settings/                       # Profil Bisnis, Bank Dinamis, Webhook Backup, Diagnostik
├── shared/
│   └── widgets/                        # AppShell, AppCard, StatusBadge, StatCard, AppPaginationBar, ConfirmationDialog
├── firebase_options.dart               # Kredensial Firebase Multi-Platform resmi
└── main.dart                           # Inisialisasi Firebase, Locale ID, SharedPreferences, & runApp
```

---

## ⚙️ 5. Logika Bisnis Kunci yang Wajib Dipertahankan

### A. Status Pelanggan Dinamis (Zero Inconsistency)
- Status pelanggan (`active`, `inactive`, `archived`) **tidak boleh** statis jika memiliki relasi VPS.
- Di `CustomerRepository`, status dihitung secara dinamis:
  - `archived`: Jika flag `isArchived == true`.
  - `active`: Memiliki minimal 1 layanan VPS aktif yang masa berlakunya belum lewat (`endDate > now`).
  - `inactive`: Tidak memiliki VPS aktif atau seluruh masa berlaku VPS telah kedaluwarsa.

### B. Profil Perusahaan & Brand Dinamis
- Nama aplikasi dan perusahaan di sidebar navigation dan top bar [app_shell.dart](file:///d:/riset/fuchuragent/lib/shared/widgets/app_shell.dart) serta dashboard **TIDAK BOLEH** di-hardcode ke string statis.
- Selalu baca dari:
  ```dart
  final settings = ref.watch(systemSettingsProvider).asData?.value;
  final effectiveAppName = (settings?.brandName.isNotEmpty ?? false) ? settings!.brandName : AppConstants.appName;
  final effectiveCompanyName = (settings?.companyName.isNotEmpty ?? false) ? settings!.companyName : AppConstants.companyName;
  ```

### C. Metode Pembayaran & Rekening Dinamis
- Daftar rekening pembayaran pada dialog tagihan, pembayaran, dan pengeluaran harus mengambil data dari `settings.paymentMethods` yang berstatus `isActive == true`.
- Rekening dapat ditambah, diubah nomor rekeningnya, atau dinonaktifkan langsung oleh admin melalui menu **Pengaturan > Rekening & Pembayaran** tanpa merusak data lama.

### D. Penomoran Otomatis Berurutan
- **Pelanggan**: `CUS-001`, `CUS-002`, dst. (dihitung otomatis dari `calculateNextCustomerId`).
- **Pengeluaran**: `EXP-001`, `EXP-002`, dst. (dihitung otomatis dari `calculateNextExpenseNumber`).
- **Tagihan**: `INV-YYYYMM-XXXX` (menggunakan atomic counter pada Firestore `app_settings/invoice_counter`).

### E. Rumus Laba Bersih & Arus Kas
$$\text{Laba Bersih} = \text{Total Kas Masuk Diterima (Payments)} - \text{Total Kas Keluar (Expenses)}$$
- Piutang belum lunas (`unpaid` / `partial`) tidak dihitung sebagai uang kas masuk aktual sampai tercatat di koleksi `payments`.

---

## 🛡️ 6. Keamanan & Peran Akses (RBAC)

Aturan keamanan Firebase Firestore ([firestore.rules](file:///d:/riset/fuchuragent/firestore.rules)) membagi otoritas:

1. **Super Admin**:
   - Akun root email `iqbal140605@gmail.com` atau pengguna dengan atribut `role == 'superadmin'`.
   - Memiliki hak mutlak menghapus data permanen, mengubah role admin lain, dan reset konfigurasi.
2. **Administrator**:
   - Pengguna dengan atribut `role == 'admin'`.
   - Mengelola pelanggan, layanan VPS, menerbitkan tagihan, memverifikasi pembayaran, mencatat biaya, dan mengatur profil bisnis.
3. **Staff**:
   - Pengguna dengan atribut `role == 'staff'`.
   - Memantau operasional layanan VPS, mengirimkan pengingat WhatsApp, dan melihat tagihan.

---

## 📋 7. Cheat Sheet Perintah untuk AI Agent & Developer

```bash
# 1. Menjalankan Analisis Statis Kode (Wajib 0 error sebelum selesai turn)
flutter analyze

# 2. Menjalankan Seluruh Unit Test
flutter test

# 3. Menjalankan Aplikasi di Platform Tertentu
flutter run -d chrome     # Web
flutter run -d windows    # Windows Desktop
flutter run -d android    # Android Device / Emulator

# 4. Deploy Aturan Keamanan & Indeks Firestore
firebase deploy --only firestore:rules,firestore:indexes

# 5. Build Paket Rilis Android APK
flutter build apk --release

# 6. Alur Wajib Selesai Task (Commit & Push ke GitHub)
git add .
git commit -m "feat/fix/chore: deskripsi ringkas perubahan"
git push origin main
```

---

## ⚠️ 8. Hal-Hal yang Dilarang (Do Not Do)

1. ❌ **JANGAN** membuat file dummy data (JSON/CSV) di dalam assets atau lib untuk dibaca saat runtime.
2. ❌ **JANGAN** menggunakan nama koleksi `'services'` (gunakan `'vps_services'`).
3. ❌ **JANGAN** menggunakan nama koleksi `'audit_logs'` (gunakan `'activity_logs'`).
4. ❌ **JANGAN** mengubah status tagihan langsung dari UI tanpa melalui `recordPayment()` atau transaksi atomik.
5. ❌ **JANGAN** membypass pengecekan otentikasi Firebase Auth.
6. ❌ **JANGAN** menghapus konfirmasi aksi CRUD destruktif (`ConfirmationDialog`).
7. ❌ **JANGAN** membiarkan perubahan task tertinggal di lokal tanpa di-commit dan di-push ke repositori GitHub.

---
*Dokumen ini adalah acuan standar pengembangan untuk seluruh modul di repositori FuchurAgent.*
