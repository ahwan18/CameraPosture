# Pencak Silat Pose Trainer

Dua aplikasi iOS yang saling terhubung untuk membantu pemula pencak silat berlatih Jurus Satu IPSI menggunakan Vision Framework dan pose detection.

## 📱 Aplikasi

### 1. PoseToJsonConverter
Aplikasi untuk mengkonversi foto pose pencak silat menjadi data JSON yang dapat digunakan untuk evaluasi.

**Fitur:**
- Upload atau ambil foto pose
- Deteksi otomatis joint/sendi menggunakan Vision Framework
- **Background gambar referensi** dengan overlay joint yang dapat diedit
- **Drag & drop joint** dengan visual feedback yang lebih baik
- **Hapus joint** yang tidak diperlukan
- Tandai joint sebagai:
  - **Normal** (biru): Joint biasa
  - **Ignored** (abu-abu): Diabaikan saat evaluasi
  - **Important** (merah): Harus benar posisinya
- **Share JSON via WhatsApp/Email/Messages**
- **Copy JSON ke clipboard** untuk paste manual

### 2. SilatTrainer
Aplikasi utama untuk latihan pencak silat dengan feedback real-time.

**Fitur:**
- Kitab Jurus: Gallery 7 pose Jurus Satu IPSI
- Latihan dengan kamera depan
- Deteksi pose real-time
- Visual feedback:
  - Skeleton overlay dengan warna joint (hijau/oranye/merah)
  - Panah kuning menunjukkan arah koreksi
- Audio feedback dalam bahasa Indonesia
- Timer 3 detik untuk setiap pose
- Progress tracking
- Completion badge

## 🚀 Cara Penggunaan

### Langkah 1: Persiapan Data Pose (PoseToJsonConverter)

1. Buka aplikasi **PoseToJsonConverter**
2. Untuk setiap pose (1-7):
   - **Pilih foto** dari galeri atau ambil foto baru
   - Aplikasi akan otomatis **mendeteksi joint** di atas background gambar
   - **Geser titik joint** untuk menyesuaikan posisi jika diperlukan
   - **Tap & tahan** untuk menu opsi (Normal/Ignored/Important/Hapus)
   - **Hapus joint** yang tidak diperlukan atau salah deteksi
   - Ubah **Pose ID** menjadi: `jurus1_pose1`, `jurus1_pose2`, dst.
   - Klik **"Simpan ke Koleksi"**

3. **Export/Share Data:**
   - **Copy**: Salin JSON ke clipboard
   - **Share**: Bagikan via WhatsApp/Email/Messages
   - **Bagikan Semua**: Share semua pose sekaligus

### Langkah 2: Input Data ke SilatTrainer

**Cara Manual (Copy-Paste):**
1. Dari PoseToJsonConverter, klik **"Copy"** untuk menyalin JSON
2. Buka aplikasi **SilatTrainer** 
3. Paste JSON secara manual di aplikasi (implementasi tergantung kebutuhan)

**Cara Share:**
1. Dari PoseToJsonConverter, klik **"Share"**
2. Pilih **Messages/WhatsApp/Email**
3. Kirim ke diri sendiri
4. Copy JSON dari pesan dan paste ke SilatTrainer

### Langkah 3: Latihan (SilatTrainer)

1. Buka aplikasi **SilatTrainer**
2. Di Kitab Jurus, pilih pose untuk memulai latihan
3. Klik "Mulai Latihan dari Pose X"
4. Ikuti instruksi:
   - Pastikan seluruh tubuh terlihat di kamera
   - Lakukan pose sesuai contoh
   - Perhatikan feedback visual (panah kuning)
   - Dengarkan feedback audio
   - Tahan pose selama 3 detik
5. Setelah berhasil, otomatis lanjut ke pose berikutnya
6. Selesaikan semua 7 pose untuk mendapat badge

## 🎨 Fitur GUI Terbaru

### PoseToJsonConverter
- ✅ **Background gambar referensi** - lihat pose asli di background
- ✅ **Drag & drop interaktif** - geser joint dengan smooth animation
- ✅ **Visual feedback** - joint berubah ukuran saat digeser
- ✅ **Label dinamis** - nama joint muncul saat disentuh/digeser  
- ✅ **Delete joint** - hapus joint dengan context menu atau tombol
- ✅ **Instructions overlay** - petunjuk penggunaan di layar
- ✅ **Share functionality** - bagikan JSON via aplikasi lain

## 🔧 Konfigurasi

### Mengubah Threshold Similarity
Di file `SilatTrainer/Configuration/TrainingConfig.swift`:
```swift
static var similarityThreshold: Double = 0.85 // Ubah nilai ini (0.0 - 1.0)
```

### Format JSON Pose
```json
{
  "poseId": "jurus1_pose1",
  "joints": {
    "leftElbow": { "x": 0.53, "y": 0.42, "confidence": 1.0 },
    "rightElbow": { "x": 0.66, "y": 0.43, "confidence": 1.0 }
    // ... joint lainnya
  },
  "ignoredJoints": ["leftEye", "rightEye"],
  "importantJoints": ["leftElbow", "rightElbow", "leftWrist", "rightWrist"]
}
```

## 📋 Requirements

- iOS 15.0+
- iPhone dengan kamera depan
- Xcode 14.0+

## 🛠 Teknologi

- Swift & SwiftUI
- Vision Framework untuk pose detection
- AVFoundation untuk kamera
- AVSpeechSynthesizer untuk audio feedback
- UIActivityViewController untuk sharing

## 📝 Workflow Terbaru

### PoseToJsonConverter → SilatTrainer
1. **Detect Pose** → Edit dengan drag & drop → **Share/Copy JSON**
2. **Kirim via WhatsApp/Email** → Copy text → **Paste manual ke SilatTrainer**
3. Atau **Copy to clipboard** → **Paste langsung**

### Tidak Lagi Diperlukan:
- ❌ Export ke file sistem
- ❌ Folder PoseData/
- ❌ File management manual

### Sekarang Lebih Mudah:
- ✅ Share via aplikasi yang sudah ada
- ✅ Copy-paste sederhana
- ✅ GUI yang lebih intuitif

## 🐛 Troubleshooting

**Pose tidak terdeteksi:**
- Pastikan seluruh tubuh terlihat di kamera
- Perbaiki pencahayaan ruangan
- Coba posisi yang lebih jelas/kontras dengan background

**Joint tidak bisa digeser:**
- Pastikan menekan titik joint secara langsung
- Coba tap & hold untuk context menu

**Tidak bisa share JSON:**
- Pastikan ada pose yang sudah disimpan
- Coba copy ke clipboard terlebih dahulu

**Audio feedback tidak terdengar:**
- Periksa volume device
- Pastikan tidak dalam mode silent
- Restart aplikasi jika diperlukan 