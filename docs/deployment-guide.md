# Panduan Konfigurasi & Deployment Fuchur Agent
**Aplikasi**: Fuchur Agent  
**Entitas Bisnis**: FuchurHost Solutions  
**Proyek Firebase**: `fuchuragent` (Project Number: `1050371549630`)  

---

## 1. Prasyarat Lingkungan
- **Flutter SDK**: 3.44.6 (channel stable) atau lebih baru
- **Dart SDK**: 3.12.2 atau lebih baru
- **Node.js**: v20.x atau v24.x
- **Firebase CLI**: v15.x atau lebih baru (`firebase-tools`)

---

## 2. Struktur Konfigurasi Firebase
Aplikasi telah terhubung ke proyek `fuchuragent` melalui file-file konfigurasi:
1. `firebase.json`: Konfigurasi resource Firestore, Storage, Cloud Functions, dan Flutter.
2. `.firebaserc`: Konfigurasi proyek default (`"default": "fuchuragent"`).
3. `firestore.rules`: Aturan keamanan Firestore berbasis role (Admin & Staff) dengan default deny.
4. `firestore.indexes.json`: Composite indexes untuk query multi-field (status, dueDate, endDate).
5. `storage.rules`: Validasi tipe dan batas ukuran dokumen/bukti transfer (maks 5MB).
6. `lib/firebase_options.dart`: Konfigurasi kredensial Firebase untuk platform Android, iOS, Web, dan Windows.
7. `android/app/google-services.json`: Kredensial Android client.

---

## 3. Langkah Menjalankan Aplikasi Flutter

### Mode Pengembangan (Windows / Web / Mobile)
1. Unduh seluruh dependensi:
   ```bash
   flutter pub get
   ```
2. Jalankan pada platform Windows desktop:
   ```bash
   flutter run -d windows
   ```
3. Atau jalankan pada peramban Web:
   ```bash
   flutter run -d chrome
   ```
4. Atau pada perangkat Android:
   ```bash
   flutter run -d android
   ```

---

## 4. Deploy Backend Cloud Functions

1. Masuk ke direktori `functions/`:
   ```bash
   cd functions
   npm install
   ```
2. Deploy seluruh fungsi ke Firebase Cloud:
   ```bash
   firebase deploy --only functions
   ```
3. Endpoint callable yang disediakan:
   - `bootstrapAdmin`: Inisialisasi administrator pertama dengan aman.
   - `createInvoice`: Penghitungan otomatis subtotal, diskon, dan nomor tagihan unik `INV-YYYYMM-XXXX`.
   - `recordPayment`: Pencatatan transaksi pembayaran dengan pencegahan idempotensi dan pembaharuan saldo tagihan.
   - `reversePayment`: Koreksi/pembatalan transaksi pembayaran dengan catatan audit log.
   - `renewService`: Perpanjangan masa aktif VPS secara aman dan konsisten.
   - `checkExpiringServices`: Scheduled function setiap 24 jam untuk pengingat masa kedaluwarsa (30, 14, 7, 3, 1 hari).

---

## 5. Deploy Security Rules & Indexes

1. Deploy aturan keamanan Firestore:
   ```bash
   firebase deploy --only firestore:rules
   ```
2. Deploy composite indexes Firestore:
   ```bash
   firebase deploy --only firestore:indexes
   ```
3. Deploy aturan penyimpanan Cloud Storage:
   ```bash
   firebase deploy --only storage
   ```

---

## 6. Menjalankan Firebase Emulator Suite
Untuk pengujian lokal tanpa membebani kuota produksi:
```bash
firebase emulators:start
```

---

## 7. Prosedur Backup & Pemulihan Firestore
1. **Ekspor Terjadwal (GCP Managed Export)**:
   - Gunakan Google Cloud Console atau Cloud Scheduler + Cloud Functions untuk menjadwalkan ekspor harian ke Cloud Storage Bucket:
     ```bash
     gcloud firestore export gs://fuchuragent-backups/daily-$(date +%Y%m%d)
     ```
2. **Pemulihan Data (Import)**:
   ```bash
   gcloud firestore import gs://fuchuragent-backups/daily-YYYYMMDD
   ```

---

## 8. Panduan Menjalankan Pengujian (QA)
1. Jalankan static analysis:
   ```bash
   flutter analyze
   ```
2. Jalankan seluruh pengujian unit & widget:
   ```bash
   flutter test
   ```
