# Panduan Operasional Fuchur Agent
**Aplikasi**: Fuchur Agent  
**Entitas Bisnis**: FuchurHost Solutions  
**Target Pengguna**: Administrator & Staf Operasional  
**Zona Waktu**: Asia/Jakarta (WIB)  
**Mata Uang**: IDR (Rupiah Indonesia)  

---

## 1. Pengenalan Aplikasi
**Fuchur Agent** adalah sistem manajemen operasional dan keuangan pelanggan Virtual Private Server (VPS) yang dikembangkan khusus untuk **FuchurHost Solutions**. Aplikasi ini menggabungkan antarmuka modern Flutter dengan keandalan infrastruktur serverless Firebase (Authentication, Cloud Firestore, Cloud Functions, Cloud Storage) untuk memberikan kontrol penuh atas siklus hidup VPS, penerbitan tagihan, penerimaan pembayaran, perpanjangan otomatis, dan audit trail operasional.

---

## 2. Alur Autentikasi & Bootstrap Administrator Pertama
Untuk memastikan keamanan sistem dan mencegah akun administrator publik tanpa pengawasan, Fuchur Agent menggunakan alur bootstrap aman:

### Inisialisasi Administrator Pertama
1. Daftarkan akun pertama di Firebase Authentication menggunakan email resmi administrator FuchurHost.
2. Panggil Cloud Function `bootstrapAdmin` (tersedia via Firebase CLI atau console) dengan payload:
   ```json
   {
     "secret": "FUCHUR_BOOTSTRAP_SECURE_TOKEN_2026",
     "email": "admin@fuchurhost.com",
     "name": "Super Administrator"
   }
   ```
3. Cloud Function akan memberikan custom claims `{ role: 'admin' }` dan membuat dokumen profil di koleksi `users`.
4. Setelah terinisialisasi, administrator dapat login melalui layar **Login** Fuchur Agent dan mengelola akun staf baru melalui menu **Pengguna & Hak Akses**.

### Hak Akses (Role-Based Access Control)
- **Administrator**:
  - Akses penuh seluruh menu: Dashboard, Pelanggan, Layanan, Paket, Tagihan, Pembayaran, Perpanjangan, Impor, Laporan, Notifikasi, Audit Log, dan Pengaturan Pengguna.
  - Memiliki wewenang mengubah harga paket, membatalkan transaksi keuangan, dan menambah akun staf.
- **Staf**:
  - Akses operasional harian: Melihat dan mencatat pelanggan, memantau status VPS, membuat tagihan, dan mencatat pembayaran.
  - Dibatasi dari perubahan peran pengguna dan pembatalan permanen tagihan keuangan.

---

## 3. Dashboard Eksekutif & Pemantauan Real-Time
Dashboard menampilkan indikator kinerja utama (KPI) operasional yang bersumber langsung dari Cloud Firestore:
- **Total & Pelanggan Aktif**: Jumlah entitas pelanggan yang terdaftar dan memiliki kontrak aktif.
- **Total & Layanan Aktif**: Jumlah instance VPS yang sedang beroperasi di infrastruktur FuchurHost.
- **Layanan Mendekati Jatuh Tempo**: VPS yang masa berlakunya akan berakhir dalam 7 hari ke depan.
- **Layanan Kedaluwarsa**: VPS yang telah melewati batas tanggal akhir masa aktif.
- **Tagihan Belum Dibayar**: Akumulasi tagihan dengan status `Belum Dibayar` atau `Dibayar Sebagian`.
- **Tagihan Terlambat**: Tagihan yang melewati tanggal jatuh tempo tanpa pelunasan.
- **Total Pembayaran Diterima**: Total uang masuk aktual yang telah berhasil diverifikasi.
  > [!IMPORTANT]
  > Sesuai prinsip akuntansi ketat FuchurHost, tagihan belum dibayar **TIDAK PERNAH** dihitung sebagai pendapatan yang diterima.

---

## 4. Manajemen Pelanggan (Customer Management)
### Fitur:
1. **Daftar & Pencarian**:
   - Cari pelanggan berdasarkan nama, email, nomor WhatsApp, atau ID pelanggan (`CUS-XXXX`).
   - Filter pelanggan berdasarkan status: `Aktif`, `Nonaktif`, atau `Semua`.
2. **Tambah / Edit Pelanggan**:
   - Formulir validasi mencakup Nama Lengkap / Perusahaan, Email, No. WhatsApp, Alamat, dan Catatan Internal.
3. **Detail Pelanggan Terpadu**:
   - Tab **Layanan VPS**: Melihat seluruh VPS yang dimiliki oleh pelanggan tersebut (1 pelanggan dapat memiliki banyak VPS).
   - Tab **Riwayat Tagihan**: Daftar tagihan beserta status pelunasan.
   - Tab **Riwayat Pembayaran**: Riwayat kwitansi pembayaran aktual.
4. **Proteksi Pengarsipan**:
   - Pelanggan yang memiliki riwayat transaksi atau layanan aktif tidak dapat dihapus secara permanen; sistem menyediakan opsi arsip untuk melindungi audit trail.

---

## 5. Katalog Paket VPS & Diskon Durasi
Fuchur Agent menyediakan katalog paket VPS yang dapat disesuaikan spesifikasi dan harganya:
- **Spesifikasi Referensi Bawaan**:
  - **Basic**: 1 vCPU, 1 GB RAM, 20 GB HDD
  - **Standard**: 2 vCPU, 2 GB RAM, 40 GB HDD
  - **Semi Pro**: 2 vCPU, 4 GB RAM, 80 GB HDD
  - **Pro**: 4 vCPU, 8 GB RAM, 120 GB HDD
- **Tingkat Diskon Durasi**:
  - 1 Bulan: 8%
  - 3 Bulan: 10%
  - 6 Bulan: 12%
  - 12 Bulan: 15%
- **Snapshot Integritas Harga**:
  - Saat tagihan diterbitkan, Fuchur Agent membuat snapshot harga dan spesifikasi paket pada dokumen tagihan. Perubahan harga paket di masa depan tidak akan merusak riwayat keuangan masa lalu.

---

## 6. Pengelolaan Layanan VPS
### Status Layanan:
- **Pending**: VPS baru dipesan, menunggu konfigurasi atau pembayaran awal.
- **Aktif**: VPS beroperasi normal.
- **Jatuh Tempo**: Masa aktif VPS berakhir hari ini atau dalam masa tenggang.
- **Ditangguhkan**: VPS dihentikan sementara (misal: pelanggaran TOS atau kendala teknis).
- **Kedaluwarsa**: Masa aktif telah berakhir dan belum diperpanjang.
- **Dibatalkan**: Layanan dihentikan permanen atas permintaan pelanggan.

> [!NOTE]
> Status operasional VPS dipisahkan secara tegas dari status pembayaran. Layanan tidak ditangguhkan secara serampangan hanya karena keterlambatan tanpa konfirmasi administrator.

> [!CAUTION]
> Dilarang keras menyimpan password root atau private key SSH pelanggan pada kolom catatan biasa. Gunakan manajemen kredensial terenkripsi yang sesuai.

---

## 7. Tagihan & Pembayaran (Billing & Payments)
### Siklus Tagihan:
1. **Pembuatan Tagihan**: Diterbitkan melalui menu Tagihan dengan nomor unik berformat `INV-YYYYMM-XXXX`.
2. **Status Tagihan**:
   - `Draft`: Konsep awal sebelum dirilis ke pelanggan.
   - `Belum Dibayar`: Belum ada pembayaran yang diterima.
   - `Dibayar Sebagian`: Pembayaran diterima namun belum mencukupi total tagihan.
   - `Lunas`: Total pembayaran yang diverifikasi sama atau melebihi total tagihan.
   - `Terlambat`: Tagihan melewati batas tanggal jatuh tempo.
   - `Dibatalkan`: Tagihan dibatalkan secara sah oleh administrator.

### Pencatatan Pembayaran:
- Buka detail tagihan atau menu **Pembayaran** -> Klik **Catat Pembayaran**.
- Masukkan nominal pembayaran (mendukung cicilan / pembayaran sebagian), tanggal pembayaran, metode (Transfer BCA, QRIS, Tunai, dll.), dan nomor referensi transaksi bank.
- Sistem menggunakan transaksi server Cloud Functions dengan **Idempotency Key** unik untuk mencegah pencatatan ganda akibat klik tombol berulang.
- Pembatalan transaksi (reversal) hanya dapat dilakukan oleh Administrator dan otomatis mencatat alasan pembatalan ke Audit Log.

---

## 8. Modul Perpanjangan Layanan (Renewals)
1. **Filter Pengingat**:
   - Filter cepat untuk memantau layanan yang akan berakhir dalam rentang **30 Hari**, **14 Hari**, **7 Hari**, **3 Hari**, dan **1 Hari**.
2. **Aturan Perpanjangan**:
   - **Perpanjangan Sebelum Tanggal Akhir**: Durasi baru ditambahkan secara mulus dari tanggal akhir sebelumnya (tidak ada masa aktif yang hangus).
   - **Perpanjangan Setelah Kedaluwarsa**: Tanggal baru dihitung dari tanggal pelunasan perpanjangan sesuai kebijakan administrator.
3. **Pencegahan Race Condition**:
   - Transaksi database Firestore mengunci dokumen layanan saat perpanjangan diproses untuk mencegah dua staf memperpanjang layanan yang sama pada detik yang bersamaan.

---

## 9. Impor Data Google Sheets / CSV
Fuchur Agent menyediakan modul impor cerdas untuk migrasi data dari Google Sheets pelanggan FuchurHost Solutions:

### Langkah Operasional Impor:
1. Buka menu **Impor Data** di sidebar.
2. Anda dapat mengimpor dengan 2 cara:
   - **Gunakan Dataset Terverifikasi**: Klik tombol **"Gunakan Data Google Sheets Lokal (19 Baris)"** untuk langsung membaca dataset tervalidasi yang telah diunduh dari spreadsheet resmi.
   - **Unggah File CSV Baru**: Klik **"Pilih Berkas CSV..."** untuk mengunggah ekspor CSV terbaru dari Google Drive/Sheets.
3. **Pratinjau & Validasi**:
   - Sistem akan memetakan kolom spreadsheet (`ID Customer`, `Nomor HP`, `Paket`, `Domain`, `Nominal`, `Mulai`, `Akhir`, `Status`).
   - Normalisasi otomatis terhadap typo (contoh: status `"Actice"` otomatis diubah menjadi `"active"`).
   - Deteksi baris placeholder kosong (`Cus-011` s/d `Cus-019`) sehingga tidak mengotori database Firestore.
4. **Konfirmasi & Proses Bertahap**:
   - Review ringkasan: jumlah baris valid, baris kosong, dan potensi duplikasi domain.
   - Klik **"Konfirmasi & Simpan ke Database"**. Sistem akan memproses penyimpanan ke Firestore dengan status progres realtime.
   - Riwayat pekerjaan dicatat di koleksi `import_jobs`.

---

## 10. Laporan & Ekspor Data
Menu **Laporan** menyediakan rekapitulasi data siap unduh:
1. **Daftar Pelanggan**: Data lengkap kontak dan status akun.
2. **Inventaris Layanan VPS**: Rekap hostname, spesifikasi vCPU/RAM/Storage, dan masa berlaku.
3. **Tagihan Belum Lunas**: Daftar tagihan jatuh tempo untuk tindak lanjut penagihan.
4. **Penerimaan Pembayaran**: Rekap kas masuk berdasarkan rentang tanggal.
5. **Ekspor CSV**: Seluruh tabel laporan dapat diekspor menjadi file `.csv` dengan satu klik untuk keperluan pembukuan eksternal dan akuntansi.

---

## 11. Audit Log & Keamanan Sistem
- Setiap tindakan penting (pembuatan tagihan, pencatatan pembayaran, pembatalan pembayaran, perpanjangan VPS, impor CSV, perubahan peran staf) secara otomatis tercatat di menu **Audit Log**.
- Informasi yang dicatat mencakup: Nama Pelaksana, ID Pengguna, Jenis Aksi, Rincian, dan Waktu Eksekusi (WIB).
- Audit log berstatus **Read-Only** di level Firestore Security Rules dan tidak dapat dimanipulasi oleh siapapun dari sisi client.
