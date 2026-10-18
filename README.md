# 🚀 Fuchur Agent

> **Enterprise ERP & Cloud Infrastructure Management System**  
> Sistem Manajemen Layanan VPS Hosting, Penagihan Otomatis, Pembukuan Kas, Pengingat WhatsApp, dan Pencadangan Data Google Sheets.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%203.x-blueviolet)](https://riverpod.dev)
[![Tests](https://img.shields.io/badge/Tests-105%2F105%20Passing-brightgreen)](#-pengujian-otomatis--kualitas-kode)
[![License](https://img.shields.io/badge/License-Proprietary-red)](#)

---

## 📑 Daftar Isi

1. [Tentang Fuchur Agent](#-tentang-fuchur-agent)
2. [Teknologi & Stack Arsitektur](#-teknologi--stack-arsitektur)
3. [Struktur Direktori Proyek](#-struktur-direktori-proyek)
4. [Fitur-Fitur Utama dari A sampai Z](#-fitur-fitur-utama-dari-a-sampai-z)
   - [A. Autentikasi & Kontrol Hak Akses (RBAC)](#a-autentikasi--kontrol-hak-akses-rbac)
   - [B. Dashboard Monitoring Real-Time](#b-dashboard-monitoring-real-time)
   - [C. Manajemen Pelanggan (Customers)](#c-manajemen-pelanggan-customers)
   - [D. Manajemen Layanan VPS & Server](#d-manajemen-layanan-vps--server)
   - [E. Katalog Paket Layanan VPS](#e-katalog-paket-layanan-vps)
   - [F. Faktur & Penagihan (Invoices)](#f-faktur--penagihan-invoices)
   - [G. Pencatatan Pembayaran Masuk (Payments)](#g-pencatatan-pembayaran-masuk-payments)
   - [H. Kelola Pengeluaran Operasional (Expenses)](#h-kelola-pengeluaran-operasional-expenses)
   - [I. Pemantauan & Analisis Keuangan (Finance Monitoring)](#i-pemantauan--analisis-keuangan-finance-monitoring)
   - [J. Monitoring Perpanjangan (Renewals)](#j-monitoring-perpanjangan-renewals)
   - [K. Integrasi Pengingat WhatsApp Dinamis](#k-integrasi-pengingat-whatsapp-dinamis)
   - [L. Pengaturan Sistem Lanjutan (System Settings)](#l-pengaturan-sistem-lanjutan-system-settings)
   - [M. Metode Pembayaran Dinamis (Dynamic Bank Accounts)](#m-metode-pembayaran-dinamis-dynamic-bank-accounts)
   - [N. Cadangan Data Otomatis ke Google Sheets](#n-cadangan-data-otomatis-ke-google-sheets)
   - [O. Notifikasi Lokal & Saluran Sistem OS Android](#o-notifikasi-lokal--saluran-sistem-os-android)
   - [P. Audit Log Aktivitas Sistem](#p-audit-log-aktivitas-sistem)
   - [Q. Manajemen Profil Pengguna & Kata Sandi](#q-manajemen-profil-pengguna--kata-sandi)
   - [R. Persistensi State Tema (Theme State Persistence)](#r-persistensi-state-tema-theme-state-persistence)
   - [S. Dialog Konfirmasi Aman (CRUD Protections)](#s-dialog-konfirmasi-aman-crud-protections)
5. [Integrasi Google Sheets Backup](#-integrasi-google-sheets-backup)
6. [Panduan Instalasi & Menjalankan Aplikasi](#-panduan-instalasi--menjalankan-aplikasi)
7. [Pengujian Otomatis & Kualitas Kode](#-pengujian-otomatis--kualitas-kode)
8. [Pengaturan Notifikasi di HP Android](#-pengaturan-notifikasi-di-hp-android)

---

## 💡 Tentang Fuchur Agent

**Fuchur Agent** adalah aplikasi manajemen operasional dan keuangan komprehensif yang dirancang khusus untuk penyedia layanan web hosting, server VPS cloud, dan infrastruktur IT. Aplikasi ini menggabungkan manajemen siklus hidup server, otomatisasi tagihan pelanggan, buku kas operasional, analitik keuangan, serta sistem notifikasi omnichannel (WhatsApp & Push Notification Sistem) dalam satu platform yang responsif untuk desktop dan mobile.

---

## 🛠 Teknologi & Stack Arsitektur

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x) Multi-platform (Android, Windows, iOS, Web).
- **State Management**: [Riverpod 3.x](https://riverpod.dev) (*NotifierProvider*, *StreamProvider*, *FutureProvider*).
- **Database & Backend**: [Firebase Firestore](https://firebase.google.com/docs/firestore) (Penyimpanan data cloud real-time).
- **Autentikasi**: [Firebase Authentication](https://firebase.google.com/docs/auth) (Email & Password terenkripsi).
- **Routing**: [GoRouter 17.x](https://pub.dev/packages/go_router) dengan *ShellRoute* navigasi terpadu.
- **Penyimpanan Lokal**: [shared_preferences](https://pub.dev/packages/shared_preferences) untuk persistensi preferensi tema dan setting perangkat.
- **Notifikasi Native**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) dengan registrasi 3 Notification Channel OS Android.
- **Integrasi Eksternal**: Google Apps Script Webhook (Google Sheets API) & WhatsApp Deep Link (`wa.me`).
- **Visualisasi Data**: [fl_chart](https://pub.dev/packages/fl_chart) untuk diagram lingkaran (Pie Chart) dan analitik keuangan.

---

## 📁 Struktur Direktori Proyek

Proyek ini dibangun menggunakan pendekatan **Feature-First Architecture** yang memisahkan logika domain secara modular:

```text
fuchuragent/
├── android/                             # Konfigurasi native Android OS, Manifest, Gradle
├── lib/
│   ├── core/                            # Fondasi aplikasi inti
│   │   ├── constants/app_constants.dart # Format Rupiah, tanggal ID, konstanta warna
│   │   ├── providers/app_providers.dart # Riverpod domain repository providers & Theme persistence
│   │   ├── router/app_router.dart       # Konfigurasi 18 rute GoRouter & auth guard
│   │   └── theme/app_theme.dart         # Skema tema Dark Mode & Light Mode
│   ├── features/                        # Modul fitur fungsional
│   │   ├── audit/                       # Riwayat aktivitas audit log admin
│   │   ├── auth/                        # Model pengguna, repositori login, dan sesi
│   │   ├── customers/                   # CRUD pelanggan, pencarian, detail, & arsip
│   │   ├── dashboard/                   # Kartu ringkasan KPI dan grafik layanan
│   │   ├── expenses/                    # Pencatatan kas keluar & nomor urut EXP-XXX
│   │   ├── finance/                     # Pemantauan arus kas, laba bersih, debt aging, & CSV
│   │   ├── imports/                     # Impor data massal CSV pelanggan & layanan
│   │   ├── invoices/                    # Penerbitan tagihan & kalkulasi jatuh tempo
│   │   ├── notifications/               # Saluran notifikasi Android & background sync
│   │   ├── packages/                    # Katalog spesifikasi paket VPS
│   │   ├── payments/                    # Verifikasi pembayaran masuk & rekonsiliasi
│   │   ├── profile/                     # Informasi akun admin & ganti password
│   │   ├── renewals/                    # Monitoring masa aktif VPS & perpanjangan
│   │   ├── reports/                     # Rekap laporan operasional & keuangan
│   │   └── settings/                    # Konfigurasi bisnis, WA template, & Sheets backup
│   ├── shared/                          # Komponen UI global (Card, Badge, Dialog, Shell)
│   └── main.dart                        # Titik masuk aplikasi, inisialisasi Firebase & SharedPreferences
└── test/
    ├── unit/                            # 16 berkas unit testing (101 pengujian)
    └── widget_test.dart                 # Pengujian komponen UI & status badge
```

---

## 🌟 Fitur-Fitur Utama dari A sampai Z

### A. Autentikasi & Kontrol Hak Akses (RBAC)
- Menggunakan Firebase Authentication dengan sesi persisten.
- Mendukung 3 tingkatan peran (*Role-Based Access Control*):
  - **Super Admin**: Memiliki akses penuh termasuk manajemen admin lain, reset sistem, dan audit log.
  - **Administrator**: Memiliki hak kelola transaksi, operasional VPS, keuangan, dan pengaturan.
  - **Staf Teknis**: Berfokus pada pemantauan VPS, reminder WhatsApp, dan penanganan tiket operasional.

### B. Dashboard Monitoring Real-Time
- **Statistik KPI Utama**: Total Pelanggan Aktif, Server VPS Beroperasi, Tagihan Tertunda, dan Laba Bersih (*Net Profit = Pemasukan - Pengeluaran*).
- **Aksi Cepat (*Quick Actions*)**: Catat Pembayaran, Pelanggan Baru, dan Tambah VPS.
- **Grafik Sebaran Layanan**: Menampilkan sebaran paket VPS yang sedang disewa pelanggan.

### C. Manajemen Pelanggan (Customers)
- **ID Otomatis Berurutan**: Pembuatan otomatis ID pelanggan berformat unik (`Cus-001`, `Cus-002`, dst.) dengan tombol generator cerdas.
- **Pencarian Cepat**: Filter pencarian real-time berdasarkan nama pelanggan, nomor WhatsApp/telepon, atau ID pelanggan.
- **Status Siklus Hidup**: Pelanggan diklasifikasikan sebagai *Aktif*, *Belum Ada Layanan*, atau *Diarsipkan*.
- **Detail Pelanggan Terpadu**: Halaman detail yang menampilkan riwayat seluruh server VPS, daftar tagihan, dan tombol kontak WhatsApp langsung.

### D. Manajemen Layanan VPS & Server
- **Pencatatan Konfigurasi Teknis**: Nama server, domain/subdomain, IP Address, vCPU, RAM (GB), Penyimpanan Storage SSD/NVMe (GB), sistem operasi (Linux/Windows), dan panel kontrol (cPanel, aapanel, dsb.).
- **Status Operasional**:
  - `active` (Server Aktif & Berjalan)
  - `pending` (Sedang Diproses/Provisioning)
  - `suspended` (Diisolir karena Tagihan Belum Lunas)
  - `expired` (Kedaluwarsa)
- **Kalkulasi Biaya Sewa**: Nominal sewa bulanan/tahunan yang terhubung langsung ke modul tagihan.

### E. Katalog Paket Layanan VPS
- Daftar paket VPS standar (*Starter, Basic, Business, Enterprise, Pro Cloud*) dengan spesifikasi bawaan dan harga acuan untuk mempermudah pendaftaran server baru.

### F. Faktur & Penagihan (Invoices)
- **Nomor Invoice Otomatis**: Generator nomor faktur dengan tanggal dan nomor urut.
- **Kalkulasi Otomatis**: Subtotal, diskon potongan harga, dan total akhir tagihan.
- **Status Penagihan**:
  - `unpaid`: Tagihan diterbitkan dan menunggu pembayaran.
  - `paid`: Lunas terverifikasi.
  - `overdue`: Jatuh tempo terlewati namun belum diselesaikan.
  - `cancelled`: Tagihan dibatalkan.

### G. Pencatatan Pembayaran Masuk (Payments)
- Formulir verifikasi penerimaan pembayaran pelanggan dengan nominal, metode transfer (BCA, Mandiri, BRI, QRIS, dsb.), dan nomor referensi transaksi.
- Pembayaran lunas otomatis mengubah status invoice menjadi `paid` dan memperbarui masa aktif layanan yang bersangkutan.

### H. Kelola Pengeluaran Operasional (Expenses)
- **Nomor Urut Transaksi Kas Keluar**: Penomoran otomatis format `EXP-001`, `EXP-002`, dst.
- **Kategori Beban Biaya**: Server & Data Center, Lisensi Software, Jaringan & Internet, Pembelian Domain, Perangkat Keras, dan Operasional Kantor.
- **Pengurangan Laba Bersih**: Beban kas keluar secara otomatis mengurangi total pendapatan kotor pada kartu laba bersih Dashboard dan Pusat Keuangan.
- **Akses Eksklusif Menu**: Menu *"Kelola Pengeluaran"* dapat diakses melalui Sidebar Desktop dan Menu Grid Mobile.

### I. Pemantauan & Analisis Keuangan (Finance Monitoring)
- **Filter Rentang Waktu (*Horizon*)**: Bulan Ini, Kuartal Ini, Tahun Ini, dan Seluruh Waktu.
- **Arus Kas Masuk vs Kas Keluar**: Membandingkan total kas diterima pelanggan dengan total pengeluaran operasional secara real-time.
- **Alokasi Beban (*Pie Chart*)**: Visualisasi proporsi pengeluaran berdasarkan kategori biaya.
- **Tabel Penuaan Piutang (*Aging Receivables*)**: Memetakan tagihan jatuh tempo yang belum terbayar (> 1 hari, > 7 hari, > 30 hari).
- **Ekspor Buku Kas CSV**: Mengunduh seluruh rincian transaksi buku besar ke berkas CSV standar Excel.

### J. Monitoring Perpanjangan (Renewals)
- Pemantauan server yang memasuki masa kritis perpanjangan:
  - *Mendekati Kedaluwarsa* (H-7 hingga H-1).
  - *Kedaluwarsa Hari Ini*.
  - *Telah Kedaluwarsa*.
- **Dialog Perpanjangan Cepat**: Memperpanjang layanan dengan pilihan durasi (1 bulan, 3 bulan, 6 bulan, 12 bulan) yang otomatis menghitung tanggal baru dan menerbitkan tagihan.

### K. Integrasi Pengingat WhatsApp Dinamis
- **Generator Teks Pengingat Cerdas**: Membuat pesan pengingat siap kirim yang otomatis mengisi:
  - Nama pelanggan.
  - Nama domain/layanan VPS.
  - Sisa hari masa aktif.
  - Rincian nomor rekening bank tujuan pembayaran dari data pengaturan dinamis.
- **Aksi Satu Klik**: Tombol *Salin Teks* ke clipboard dan tombol *Kirim ke WhatsApp* yang membuka aplikasi WhatsApp langsung ke nomor pelanggan via protokol `https://wa.me/`.

### L. Pengaturan Sistem Lanjutan (System Settings)
- **Profil Bisnis**: Nama perusahaan, nama brand, email bantuan, nomor telepon operasional, alamat kantor, dan website.
- **Template Pesan WhatsApp**: Salam pembuka, badan pengingat, dan penutup/tanda tangan admin.
- **Pengaturan Tampilan Tabel**: Konfigurasi jumlah baris per halaman (10, 25, 50, 100 baris).

### M. Metode Pembayaran Dinamis (Dynamic Bank Accounts)
- Menambah, mengubah nomor rekening/nama pemilik rekening, atau menghapus metode pembayaran secara dinamis tanpa mengubah harga paket layanan.
- Mendukung berbagai jenis rekening: Transfer Bank (BCA, Mandiri, BNI, BRI), E-Wallet (GoPay, OVO, Dana), dan QRIS.
- Rekening bertanda *Default* akan otomatis tercantum pada template tagihan dan WhatsApp reminder.

### N. Cadangan Data Otomatis ke Google Sheets
- Sinkronisasi data Firebase Firestore (Pelanggan, VPS, Tagihan, Pembayaran, dan Pengeluaran) ke Spreadsheet Google Drive target secara otomatis melalui Webhook Google Apps Script (`doPost`).
- Opsi *Salin TSV ke Clipboard* untuk paste manual cepat langsung ke spreadsheet.
- Opsi *Ekspor Cadangan JSON* untuk arsip offline mandiri.

### O. Notifikasi Lokal & Saluran Sistem OS Android
- Mendaftarkan 3 Notification Channel resmi ke sistem Android OS:
  1. `fuchur_operational_alerts`: Peringatan Operasional VPS & Layanan.
  2. `fuchur_financial_alerts`: Transaksi Tagihan & Pembayaran.
  3. `fuchur_system_alerts`: Pemberitahuan Sistem & Backup Data.
- Background sync berkala setiap 15 menit untuk memantau server yang kedaluwarsa secara otomatis di latar belakang.
- Tombol *Uji Notifikasi* untuk memverifikasi fungsionalitas status bar Android / toast Windows.

### P. Audit Log Aktivitas Sistem
- Pencatatan otomatis setiap tindakan mutasi data (`CREATE`, `UPDATE`, `DELETE`, `ARCHIVE`, `EXPORT_BACKUP`, `LOGIN`) lengkap dengan identitas email admin pengubah, IP/klien, rincian entitas, dan stempel waktu (*timestamp*).

### Q. Manajemen Profil Pengguna & Kata Sandi
- Mengubah nama lengkap dan nomor telepon kontak pribadi.
- Pembaruan kata sandi akun dengan validasi keamanan dan verifikasi kata sandi lama.
- Tombol Keluar Akun (*Logout*) dengan konfirmasi keamanan.

### R. Persistensi State Tema (Theme State Persistence)
- Menggunakan `shared_preferences` untuk menyimpan preferensi tema pengguna (Dark Mode / Light Mode).
- Tema dimuat sebelum widget tree pertama kali dirender sehingga tidak ada kedipan tampilan (*zero flicker*).
- Pilihan tema tetap tersimpan permanen saat aplikasi ditutup dan dibuka kembali.

### S. Dialog Konfirmasi Aman (CRUD Protections)
- Mencegah kehilangan data atau ketidaksengajaan klik:
  - `showCreateConfirmation`: Menanyakan konfirmasi sebelum data baru didaftarkan.
  - `showUpdateConfirmation`: Menanyakan konfirmasi sebelum perubahan disimpan ke database.
  - `showDeleteConfirmation`: Dialog peringatan destruktif berwarna merah sebelum data dihapus atau diarsipkan.
  - `showLogoutDialog`: Menanyakan konfirmasi sebelum sesi akun diakhiri.

---

## 📊 Integrasi Google Sheets Backup

Aplikasi ini terhubung langsung ke Google Sheets target:
- **URL Spreadsheet**: [Buka Spreadsheet Backup](https://docs.google.com/spreadsheets/d/1Rdcg6rgp4K7qBO328qeqHfzpaaYZjcRgvsI_OQGjLkE/edit?usp=sharing)

### Struktur Lembar (*Sheets*) Target:
1. `Customers`: ID Pelanggan, Nama, Nomor WhatsApp, Email, Status, Tanggal Dibuat.
2. `VPS Services`: ID Layanan, ID Pelanggan, Nama Layanan, Domain, IP Address, vCPU, RAM, Storage, Harga Sewa, Status, Tanggal Kedaluwarsa.
3. `Invoices`: Nomor Invoice, ID Pelanggan, Subtotal, Diskon, Total, Status, Jatuh Tempo.
4. `Payments`: ID Pembayaran, Nomor Invoice, Jumlah Bayar, Metode Bayar, Referensi, Tanggal Bayar.
5. `Expenses`: Nomor Pengeluaran, Judul, Kategori, Jumlah Pengeluaran, Metode Bayar, Penerima, Tanggal.

### Pengaturan Webhook Google Apps Script:
1. Buka spreadsheet > Menu **Extensions** > **Apps Script**.
2. Salin kode generator Apps Script yang tersedia di menu aplikasi (*Pengaturan > Tab Cadangan > Buat Kode Apps Script*).
3. Klik **Deploy** > **New Deployment** > Pilih jenis **Web App**.
4. Atur *Execute as*: **Me**, dan *Who has access*: **Anyone**.
5. Salin URL Web App yang dihasilkan dan tempelkan ke kolom **Webhook URL** di Pengaturan Fuchur Agent.

---

## 🚀 Panduan Instalasi & Menjalankan Aplikasi

### Prasyarat Sistem
- **Flutter SDK**: Versi `3.24.x` atau lebih baru.
- **Dart SDK**: Versi `3.5.x` atau lebih baru.
- **Android SDK**: API level 34 (Android 14) / Min SDK 21 (Android 5.0).
- **Java Development Kit**: JDK 17.

### Langkah Instalasi

1. **Clone Repositori**:
   ```bash
   git clone https://github.com/Ballon14/fuchuragent.git
   cd fuchuragent
   ```

2. **Unduh Dependensi**:
   ```bash
   flutter pub get
   ```

3. **Konfigurasi Firebase**:
   Pastikan berkas `firebase_options.dart` telah terkonfigurasi dengan project Firebase Firestore dan Auth Anda:
   ```bash
   flutterfire configure
   ```

4. **Jalankan Aplikasi (Mode Debug/Development)**:
   ```bash
   # Di perangkat Android fisik / emulator:
   flutter run -d android

   # Di Windows Desktop:
   flutter run -d windows

   # Di Google Chrome (Web):
   flutter run -d chrome
   ```

5. **Build APK Android (Release)**:
   ```bash
   flutter build apk --release
   ```
   Berkas APK siap didistribusikan di: `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🧪 Pengujian Otomatis & Kualitas Kode

Aplikasi ini dilengkapi pengujian unit dan widget komprehensif untuk memastikan keandalan logika bisnis:

```bash
# Menjalankan seluruh rangkaian tes otomatis:
flutter test --concurrency=1

# Melakukan analisis kode statis (linting):
flutter analyze lib/ test/
```

### Hasil Uji Terkini:
- **Analisis Statis**: `No issues found!` (0 errors, 0 warnings).
- **Unit Tests**: **105 / 105 tests passed (100% Lulus)** mencakup:
  - `crud_confirmation_test.dart` (Validasi dialog konfirmasi CRUD).
  - `theme_persistence_test.dart` (Persistensi preferensi tema SharedPreferences).
  - `expense_management_test.dart` (Format nomor urut EXP-XXX & integrasi laba bersih).
  - `finance_monitoring_test.dart` (Kalkulasi arus kas & debt aging).
  - `google_sheets_backup_test.dart` (Serialisasi data sheets & Apps Script).
  - `notification_system_test.dart` (Deduplikasi alert & klasifikasi saluran).
  - `whatsapp_reminder_test.dart` (Normalisasi nomor telepon & generator pesan).
  - `logout_confirmation_test.dart` (Keamanan modal keluar akun).

---

## 📱 Pengaturan Notifikasi di HP Android

Jika menu pengaturan di HP Android menampilkan keterangan *"Aplikasi ini belum dapat mengeluarkan notifikasi"*, ikuti langkah cepat berikut:

1. Buka aplikasi **Fuchur Agent** di HP Anda.
2. Buka menu **Notifikasi** dari bilah navigasi.
3. Klik tombol **"Izinkan"** atau tombol **"Uji Notifikasi"**.
4. Buka **Pengaturan HP > Aplikasi > Fuchur Agent > Notifikasi**:
   - Status notifikasi akan berubah menjadi **Diizinkan / Aktif**.
   - Tiga saluran notifikasi resmi (*Peringatan Operasional VPS & Layanan*, *Tagihan & Pembayaran*, dan *Sistem*) akan muncul dan dapat diatur secara individual.
5. *(Opsional untuk latar belakang optimal)*: Buka menu **Baterai / Penggunaan Daya** pada info aplikasi di HP Anda > Pilih **"Tidak Dibatasi" (*Unrestricted*)** agar pemberitahuan jatuh tempo server tetap aktif saat aplikasi ditutup.

---

## 📄 Lisensi & Hak Cipta

Hak Cipta © 2026 Fuchur Host / Ballon14. Seluruh hak cipta dilindungi undang-undang.
Dilarang keras menyalin, mendistribusikan, atau memodifikasi kode ini tanpa izin tertulis dari pemilik proyek.
