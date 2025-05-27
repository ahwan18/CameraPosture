//
//  ContentView.swift
//  C3-Posture
//
//  Created by Ahmad Kurniawan Ibrahim on 27/05/25.
//

import SwiftUI

// MARK: - Tampilan Utama Aplikasi
// ContentView adalah tampilan utama yang menggabungkan kamera dan UI untuk deteksi postur
struct ContentView: View {
    // @StateObject digunakan untuk membuat dan mengelola objek yang dapat berubah
    // CameraViewModel menangani semua logika kamera dan deteksi postur
    @StateObject private var cameraViewModel = CameraViewModel()
    
    var body: some View {
        // ZStack menumpuk view-view di atas satu sama lain (seperti layer)
        ZStack {
            // Layer 1: Preview kamera sebagai background
            CameraPreview(viewModel: cameraViewModel)
                .ignoresSafeArea() // Mengabaikan safe area agar kamera fullscreen
            
            // Layer 2: Kotak biru untuk menunjukkan area deteksi person (hanya muncul saat setup mode)
            if cameraViewModel.isSetupMode, let box = cameraViewModel.personBoundingBox {
                // GeometryReader untuk mendapatkan ukuran layar
                GeometryReader { geo in
                    let w = geo.size.width  // Lebar layar
                    let h = geo.size.height // Tinggi layar
                    
                    // Konversi koordinat dari Vision (0-1) ke koordinat layar (pixel)
                    // Vision menggunakan koordinat terbalik untuk Y, jadi perlu diflip
                    let rect = CGRect(
                        x: box.minX * w,           // X position
                        y: (1 - box.maxY) * h,    // Y position (diflip)
                        width: box.width * w,     // Lebar kotak
                        height: box.height * h    // Tinggi kotak
                    )
                    
                    // Menggambar kotak dengan garis biru
                    Path { path in
                        path.addRect(rect)
                    }
                    .stroke(Color.blue, lineWidth: 3)
                }
            }
            
            // Layer 3: User Interface (tombol dan status)
            VStack {
                // Bagian atas: Tombol switch kamera
                HStack {
                    Spacer() // Mendorong tombol ke kanan
                    
                    Button(action: {
                        // Aksi untuk mengganti kamera (depan/belakang)
                        cameraViewModel.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7)) // Background semi-transparan
                            .clipShape(Circle()) // Bentuk bulat
                    }
                    .padding()
                }
                
                Spacer() // Mendorong konten ke bawah
                
                // Bagian bawah: Status dan kontrol berdasarkan mode aplikasi
                if cameraViewModel.isSetupMode {
                    // MODE SETUP: Tombol untuk menyimpan posisi target
                    Button(action: {
                        // Simpan posisi bounding box sebagai target
                        cameraViewModel.targetPersonBox = cameraViewModel.personBoundingBox
                        // Keluar dari setup mode dan mulai evaluasi postur
                        cameraViewModel.isSetupMode = false
                    }) {
                        Text("Set")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(15)
                    }
                    .padding(.bottom, 50)
                } else {
                    // MODE EVALUASI: Menampilkan status deteksi dan postur
                    
                    if !cameraViewModel.isPersonDetected {
                        // Tidak ada orang yang terdeteksi
                        Text("No person detected")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(15)
                            .padding(.bottom, 50)
                    } else if cameraViewModel.currentPoseObservation == nil {
                        // Orang terdeteksi tapi pose tidak bisa dianalisis
                        Text("Please stand in the same position")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(15)
                            .padding(.bottom, 50)
                    } else {
                        // Orang dan pose terdeteksi - tampilkan status postur
                        HStack {
                            // Icon status (centang hijau = bagus, X merah = tidak bagus)
                            Image(systemName: cameraViewModel.isPostureGood ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(cameraViewModel.isPostureGood ? .green : .red)
                            
                            // Pesan status postur
                            Text(cameraViewModel.isPostureGood ? "Good Posture!" : "Raise your arm to 30°")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(15)
                        .padding(.bottom, 10)
                        
                        // Detail error untuk tangan kiri/kanan (jika ada yang salah)
                        if !cameraViewModel.isLeftElbowGood || !cameraViewModel.isRightElbowGood {
                            VStack(spacing: 4) {
                                if !cameraViewModel.isLeftElbowGood {
                                    Text("Left arm not at 30°")
                                        .foregroundColor(.red)
                                        .bold()
                                }
                                if !cameraViewModel.isRightElbowGood {
                                    Text("Right arm not at 30°")
                                        .foregroundColor(.red)
                                        .bold()
                                }
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
        }
        // Lifecycle events: apa yang terjadi saat view muncul/hilang
        .onAppear {
            // Mulai session kamera saat view muncul
            cameraViewModel.startSession()
        }
        .onDisappear {
            // Hentikan session kamera saat view hilang (untuk menghemat battery)
            cameraViewModel.stopSession()
        }
    }
}

// Preview untuk SwiftUI Canvas (development tool)
#Preview {
    ContentView()
}
