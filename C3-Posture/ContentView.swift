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
    @StateObject private var poseSelectionViewModel = PoseSelectionViewModel()
    @State private var showingPoseSelection = false
    
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
            
            // Layer 3: Reference image overlay in pose matching mode
            if cameraViewModel.isInPoseMatchingMode, let referenceImage = cameraViewModel.selectedReferenceImage {
                VStack {
                    HStack {
                        Spacer()
                        Image(uiImage: referenceImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .padding(8)
                    }
                    Spacer()
                }
            }
            
            // Layer 4: User Interface (tombol dan status)
            VStack {
                // Bagian atas: Tombol switch kamera
                HStack {
                    Spacer() // Mendorong tombol ke kanan
                    
                    // Mode selector
                    Menu {
                        Button(action: {
                            cameraViewModel.isSetupMode = true
                            cameraViewModel.exitPoseMatchingMode()
                        }) {
                            Label("Setup Mode", systemImage: "person.fill")
                        }
                        
                        Button(action: {
                            showingPoseSelection = true
                        }) {
                            Label("Match Pose", systemImage: "person.fill.viewfinder")
                        }
                    } label: {
                        Image(systemName: cameraViewModel.isInPoseMatchingMode ? "person.fill.viewfinder" : "person.fill")
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
                } else if cameraViewModel.isInPoseMatchingMode {
                    // MODE MATCHING: Menampilkan status deteksi dan postur
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
                        Text("Stand in frame for pose detection")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(15)
                            .padding(.bottom, 50)
                    } else {
                        VStack(spacing: 10) {
                            // Match percentage and status
                            HStack {
                                Image(systemName: cameraViewModel.overallPoseMatchStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(cameraViewModel.overallPoseMatchStatus ? .green : .red)
                                
                                VStack(alignment: .leading) {
                                    Text(cameraViewModel.overallPoseMatchStatus ? "Great match!" : "Keep adjusting...")
                                        .font(.headline)
                                        .bold()
                                        .foregroundColor(.white)
                                    
                                    Text("Match: \(Int(cameraViewModel.poseMatchPercentage))%")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(15)
                            
                            // Exit button
                            Button(action: {
                                cameraViewModel.exitPoseMatchingMode()
                            }) {
                                Text("Exit Pose Matching")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.bottom, 30)
                    }
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
        .sheet(isPresented: $showingPoseSelection) {
            PoseSelectionView(
                viewModel: poseSelectionViewModel,
                isPresented: $showingPoseSelection,
                onSelectPose: { pose in
                    if let image = pose.image {
                        cameraViewModel.setReferencePose(image, name: pose.name)
                    }
                }
            )
        }
    }
}

// Preview untuk SwiftUI Canvas (development tool)
#Preview {
    ContentView()
}
