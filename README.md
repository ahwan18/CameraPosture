# C3-Posture - Camera Posture Training App

Aplikasi iOS untuk latihan postur tubuh menggunakan kamera dan deteksi pose dengan Vision framework.

## Fitur Utama

### 1. Single Pose Practice
- Pilih pose yang ingin dipraktekkan
- Sistem akan mendeteksi pose user dan membandingkannya dengan pose referensi
- Indikator visual menunjukkan seberapa cocok pose user dengan referensi

### 2. Sequential Training
- Latihan berurutan menggunakan semua pose yang tersedia
- Cocok untuk sesi latihan yang lebih komprehensif

### 3. **Positioning Box (FITUR BARU)**
Fitur baru yang memastikan user berada pada jarak optimal dari kamera untuk deteksi pose yang akurat:

#### Cara Kerja:
- **Box Overlay**: Ketika memulai pose practice, akan muncul box oranye di layar (ukuran lebih kecil untuk jarak 3m)
- **Jarak Optimal**: Box memandu user untuk posisi pada jarak **3 meter** dari kamera
- **Full Body Detection**: Memastikan seluruh tubuh user dapat terdeteksi kamera
- **Auto Transition**: Box akan berubah hijau dan hilang otomatis ketika user sudah berada pada posisi yang tepat
- **Continuous Monitoring**: Untuk Sequential Training, posisi user terus dipantau sepanjang sesi

#### Kriteria Positioning:
- **Body Height Ratio**: 40-70% dari tinggi layar (disesuaikan untuk jarak 3m)
- **Body Centering**: User harus berada di tengah frame (toleransi ±15%)
- **Full Body Visibility**: Minimal 5 dari 7 joint utama terdeteksi (kepala, bahu, pinggul, kaki)

#### Visual Feedback:
- **Box Oranye**: User belum berada pada posisi optimal
- **Box Hijau**: User sudah pada posisi yang tepat
- **Status Text**: Instruksi dan feedback real-time
- **Distance Scale**: Indikator visual untuk jarak optimal

## Teknologi

- **SwiftUI** untuk UI framework
- **Vision Framework** untuk pose detection
- **AVFoundation** untuk camera handling
- **CoreGraphics** untuk custom overlay rendering

## Struktur Proyek

```
C3-Posture/
├── Views/
│   ├── ContentView.swift          # Main app view
│   ├── CameraPreview.swift        # Camera preview + overlays
│   ├── PoseSelectionView.swift    # Pose selection interface
│   └── SequentialPoseView.swift   # Sequential training view
├── ViewModels/
│   ├── CameraViewModel.swift      # Camera & pose logic + positioning
│   ├── MainViewModel.swift        # Main app state
│   ├── PoseSelectionViewModel.swift
│   └── SequentialTrainingViewModel.swift
├── Services/
│   └── PostureService.swift      # Pose detection utilities
├── Models/
│   └── PostureModels.swift       # Data models
└── Resources/
    └── Postures/                 # Reference pose images
```

## Implementasi Positioning Box

### CameraViewModel (Updated)
- Ditambahkan properties untuk positioning state
- Fungsi `analyzeUserPositioning()` untuk validasi posisi user
- Logika untuk transition otomatis dari positioning ke pose matching

### CameraPreview (Updated)
- Kelas `PositioningBoxView` untuk rendering box overlay
- Reactive binding untuk show/hide positioning box
- Visual indicators untuk user guidance

### ContentView (Updated)
- Status display yang berbeda untuk positioning phase dan pose matching phase
- User feedback yang lebih informatif

## Cara Penggunaan

### Single Pose Practice:
1. **Buka Aplikasi** dan pilih "Single Pose Practice"
2. **Pilih Pose** yang ingin dipraktekkan dari galeri
3. **Posisioning Phase**: 
   - Ikuti box oranye yang muncul di layar (ukuran lebih kecil)
   - Posisikan diri agar seluruh tubuh berada dalam box pada jarak **3 meter**
   - Mundur atau maju hingga box berubah hijau
4. **Pose Matching Phase**:
   - Setelah box hilang, mulai lakukan pose sesuai referensi
   - Ikuti visual feedback untuk penyesuaian pose
   - Target match ≥70% untuk pose yang baik

### Sequential Training:
1. **Pilih "Sequential Training"** dari menu utama
2. **Positioning Phase** - sama seperti single pose (jarak 3 meter)
3. **Training Phase**:
   - Lakukan pose sesuai urutan yang diberikan
   - **PENTING**: Tetap berada dalam area positioning sepanjang sesi
   - **Auto Reset**: Jika keluar dari area positioning, training akan reset otomatis ke pose pertama
   - Selesaikan semua pose untuk menyelesaikan sesi

## Target Deployment

- iOS 18.4+
- iPhone/iPad dengan kamera
- Swift 5.0+

## Setup Development

1. Clone repository
2. Buka `C3-Posture.xcodeproj` di Xcode
3. Build dan run di simulator atau device

Aplikasi memerlukan akses kamera untuk berfungsi optimal, jadi testing di device fisik sangat disarankan. 