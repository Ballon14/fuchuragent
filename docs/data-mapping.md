# Dokumentasi Audit dan Pemetaan Data Google Sheets
**Aplikasi**: Fuchur Agent  
**Entitas Bisnis**: FuchurHost Solutions  
**Sumber Data**: Google Sheets (Spreadsheet Pelanggan)  
**URL Sumber**: `https://docs.google.com/spreadsheets/d/e/2PACX-1vT1izWzmNR3gtNR7XkZt7RPe6uWeHO4CHuMnyJvTP_5ucGg0XXp6hKH4niTkUIDoT4QvpotNT2SbkKj/pubhtml?gid=0&single=true`  
**Endpoint Ekspor CSV**: `https://docs.google.com/spreadsheets/d/e/2PACX-1vT1izWzmNR3gtNR7XkZt7RPe6uWeHO4CHuMnyJvTP_5ucGg0XXp6hKH4niTkUIDoT4QvpotNT2SbkKj/pub?gid=0&single=true&output=csv`  
**Tanggal Audit**: 17 Oktober 2026  

---

## 1. Hasil Pemeriksaan Akses Spreadsheet
- **Status Akses**: Berhasil diakses secara live tanpa hambatan autentikasi via HTTP / CSV Export.
- **Nama Tab**: `VPS` (`gid=0`)
- **Judul Header Lembar**: `DAFTAR CUSTOMER VPS FUCHURHOST SOLUTIONS` (terletak pada baris ke-4 lembar kerja).
- **Baris Header Tabel**: Terletak pada baris ke-7 CSV:
  ```csv
  No,ID Customer,Nomor HP,Paket,Domain,Optional,Nominal,Payment Status,Mulai,Akhir,Worker ,Payment Worker,Status
  ```

---

## 2. Struktur Kolom Asli dan Analisis Data

| No Kolom | Nama Kolom Asli | Contoh Nilai Asli | Tipe Data Asli | Catatan & Temuan Kualitas Data |
|---|---|---|---|---|
| 1 | `No` | `1`, `2`, `10` | Integer / Urutan baris | Hanya nomor urut spreadsheet. Bukan ID permanen. |
| 2 | `ID Customer` | `Cus-001` s/d `Cus-019` | String (`Cus-XXX`) | ID stabil sumber. Baris 11-19 memiliki ID namun field lain kosong. |
| 3 | `Nomor HP` | `0851-9822-6204`, `0897-8267-350` | String berformat | Terdapat variasi tanda hubung (`-`) dan panjang digit. Perlu sanitasi angka saja. |
| 4 | `Paket` | `Snipe-it Basic`, `Basic 3 Bulan`, `Basic 1 Bulan` | String teks | Menunjukkan paket VPS atau aplikasi template. |
| 5 | `Domain` | `https://arkavue.buildsys.site`, `https://puskesmaspituruh.my.id` | URL / FQDN | URL layanan VPS pelanggan. Terdapat domain duplikat di baris 9 & 10 (`https://smkn6lab.site`). |
| 6 | `Optional` | `Publish` | String | Fitur/opsi deployment tambahan. |
| 7 | `Nominal` | `"Rp77,000.00"`, `"Rp135,000.00"`, `"Rp76,000.00"`, `"Rp46,000.00"` | String mata uang | Berisi prefix `Rp`, koma pemisah ribuan, dan desimal `.00`. Wajib diparse ke integer Rupiah murni. |
| 8 | `Payment Status` | `Lunas` | String | Status pembayaran tagihan saat itu. |
| 9 | `Mulai` | `7/4/2026`, `7/18/2026` | String tanggal | Format tanggal adalah `M/D/YYYY` (contoh `7/18/2026` = 18 Juli 2026). Zona waktu Asia/Jakarta. |
| 10 | `Akhir` | `8/4/2026`, `10/18/2026` | String tanggal | Format tanggal sama `M/D/YYYY`. |
| 11 | `Worker ` | `Iqbal` | String | Nama staf pelaksana / administrator teknis penanganan. |
| 12 | `Payment Worker` | `TRUE`, `FALSE` | Boolean teks | Status pelunasan/pembayaran komisi worker internal. |
| 13 | `Status` | `Deactive`, `Actice` | String | Status operasional VPS. Catatan: ditemukan typo asli `Actice` yang bermakna `Active`. |

---

## 3. Temuan Anomali, Data Kosong, dan Duplikat

1. **Baris Kosong / Placeholder (Baris 11 - 19)**:
   - Baris 11 hingga 19 (`Cus-011` s.d `Cus-019`) hanya memiliki `ID Customer` dan `Payment Worker = FALSE`, sedangkan field lainnya (`Nomor HP`, `Paket`, `Domain`, `Nominal`, `Mulai`, `Akhir`, `Status`) kosong.
   - **Tindakan**: Sistem impor wajib mengkategorikan baris ini sebagai **Data Tidak Lengkap / Placeholder** dan tidak boleh diimpor langsung tanpa data valid, atau diberi opsi abaikan.

2. **Duplikasi / Relasi Multi-Layanan (`smkn6lab.site`)**:
   - `Cus-009` (HP: `0895-2577-7656`, domain: `https://smkn6lab.site`, periode: 22 Juli 2026 - 22 Agustus 2026, nominal: Rp76.000).
   - `Cus-010` (HP: `0895-2577-7657`, domain: `https://smkn6lab.site`, periode: 22 Agustus 2026 - 22 September 2026, nominal: Rp46.000).
   - **Tindakan**: Domain yang sama dengan nomor HP yang berselisih 1 digit dan periode yang berurutan menunjukkan perpanjangan layanan atau pelanggan yang sama mengelola domain tersebut. Di Firestore, 1 pelanggan dapat memiliki beberapa layanan VPS atau histori perpanjangan.

3. **Typo Status Asli**:
   - Terdapat nilai `Actice`. Sistem parser harus otomatis menormalkan `Actice` menjadi status standar `active` (Aktif) dan `Deactive` menjadi `deactive` / `expired`.

4. **Parsing Nominal Uang**:
   - String `"Rp135,000.00"` -> angka integer `135000` (IDR murni tanpa float).

5. **Parsing Tanggal**:
   - Format `M/D/YYYY` dikonversi ke Firestore `Timestamp` dengan zona waktu `Asia/Jakarta` (`UTC+7`).

---

## 4. Pemetaan Kolom ke Koleksi Cloud Firestore

Arsitektur Firestore memisahkan data menjadi entitas relasional yang bersih:

### A. Koleksi `customers`
| Kolom Sumber | Field Firestore | Tipe Data | Deskripsi |
|---|---|---|---|
| `ID Customer` | `sourceId` | `string` | ID referensi dari spreadsheet (contoh `Cus-001`) |
| Auto-generated / `Cus-XXX` | `id` | `string` | ID dokumen Firestore |
| Diturunkan dari domain / HP | `name` | `string` | Nama pelanggan (misal: "Customer Cus-007 (Puskesmas Pituruh)") |
| - | `email` | `string?` | Email pelanggan |
| `Nomor HP` | `phone` | `string` | Nomor WhatsApp / HP terstandar |
| `Status` | `status` | `string` | `active` / `inactive` / `archived` |
| - | `notes` | `string` | Catatan internal pelanggan |
| System | `createdAt` | `Timestamp` | Waktu pembuatan dokumen |
| System | `updatedAt` | `Timestamp` | Waktu pembaruan terakhir |

### B. Koleksi `vps_packages`
| Data Sumber | Field Firestore | Tipe Data | Deskripsi |
|---|---|---|---|
| `Paket` | `name` | `string` | Nama paket (misal: `Snipe-it Basic`, `Basic 1 Bulan`, `Basic 3 Bulan`) |
| Ditentukan | `code` | `string` | Slug paket (`snipe-it-basic`, `basic-1m`, dll.) |
| Ditentukan | `vcpu` | `int` | Jumlah vCPU (1, 2, 4) |
| Ditentukan | `ramGb` | `int` | RAM dalam GB (1, 2, 4, 8) |
| Ditentukan | `storageGb` | `int` | Kapasitas disk dalam GB |
| `Nominal` | `price` | `int` | Harga satuan dalam integer IDR |
| Analisis durasi | `durationMonths`| `int` | 1, 3, 6, 12 bulan |
| - | `isActive` | `bool` | Status keaktifan paket |

### C. Koleksi `vps_services`
| Kolom Sumber | Field Firestore | Tipe Data | Deskripsi |
|---|---|---|---|
| Auto ID | `id` | `string` | ID dokumen layanan VPS |
| `ID Customer` | `customerId` | `string` | Referensi ID pelanggan pemilik |
| Diturunkan | `serviceName` | `string` | Nama instance layanan VPS |
| `Domain` | `domain` | `string` | Domain / hostname FQDN |
| `Optional` | `deploymentType`| `string` | Opsi deployment (misal: `Publish`) |
| `Paket` | `packageId` | `string` | Referensi ke paket VPS |
| `Nominal` | `price` | `int` | Harga tagihan layanan dalam integer IDR |
| `Mulai` | `startDate` | `Timestamp` | Tanggal mulai masa aktif |
| `Akhir` | `endDate` | `Timestamp` | Tanggal berakhir masa aktif |
| `Status` | `status` | `string` | `active`, `deactive`, `expired`, `pending`, `suspended` |
| `Worker ` | `worker` | `string?` | Nama teknisi penanggung jawab |
| `Payment Worker`| `workerPaid` | `bool` | Status pembayaran honor worker |
| System | `createdAt` | `Timestamp` | Waktu pencatatan |
| System | `updatedAt` | `Timestamp` | Waktu pembaruan |

### D. Koleksi `invoices` & `payments`
| Data Terkait | Field Firestore | Tipe Data | Deskripsi |
|---|---|---|---|
| Nomor Unik | `invoiceNumber` | `string` | Format `INV-YYYYMM-XXXX` |
| `ID Customer` | `customerId` | `string` | ID pelanggan |
| Layanan Terkait| `serviceId` | `string` | ID layanan VPS |
| `Nominal` | `amount` | `int` | Total nominal tagihan (IDR) |
| `Mulai` | `issuedAt` | `Timestamp` | Tanggal terbit tagihan |
| `Akhir` | `dueDate` | `Timestamp` | Tanggal jatuh tempo |
| `Payment Status`| `status` | `string` | `paid` (Lunas), `unpaid`, `partial`, `overdue`, `cancelled` |
| `Nominal` | `paidAmount` | `int` | Akumulasi nominal yang telah dibayarkan |

---

## 5. Alur Validasi dan Impor CSV
1. **Unggah File / Tarik URL**: Pengguna dapat memilih file CSV lokal atau menyinkronkan dari URL Google Sheets publik.
2. **Parsing Header**: Deteksi baris header dan pemetaan kolom dinamis.
3. **Validasi Baris Data**:
   - Cek kelengkapan kolom wajib: `ID Customer`, `Domain`, `Nominal`, `Mulai`, `Akhir`.
   - Deteksi placeholder baris kosong (`Cus-011` s/d `Cus-019`) -> tandai untuk dilewati.
   - Sanitasi format mata uang (`Rp77,000.00` -> `77000`).
   - Sanitasi format tanggal (`7/4/2026` -> ISO 8601 / DateTime).
   - Normalisasi typo status (`Actice` -> `active`).
4. **Pratinjau & Konfirmasi Admin**: Tampilkan daftar data valid, peringatan duplikasi, dan data tidak lengkap sebelum eksekusi penyimpanan.
5. **Deduplikasi**: Pengecekan terhadap `sourceId` dan `domain` yang sudah ada di Firestore. Impor ulang tidak akan menimpa sembarangan atau menggandakan dokumen.
6. **Eksekusi Batch**: Disimpan dengan `batch write` Firestore (maksimal 400 dokumen per commit batch agar aman di bawah limit 500 operasi).
