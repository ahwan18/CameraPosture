//
//  ContentView.swift
//  C3-Posture
//
//  Created by Ahmad Kurniawan Ibrahim on 27/05/25.
//

import SwiftUI
import AVFoundation

// MARK: - Tampilan Utama Aplikasi
// ContentView adalah tampilan utama yang menggabungkan kamera dan UI untuk deteksi postur
struct ContentView: View {
    // @StateObject digunakan untuk membuat dan mengelola objek yang dapat berubah
    // CameraViewModel menangani semua logika kamera dan deteksi postur
    @StateObject private var cameraViewModel = CameraViewModel()
    @StateObject private var poseSelectionViewModel = PoseSelectionViewModel()
    @State private var showingPoseSelection = false
    @State private var showingFinishAlert = false
    @State private var nextPoseIndex = 0
    @State private var holdTimer: Timer? = nil
    @State private var holdSeconds: Double = 0
    let holdDuration: Double = 10.0
    @State private var countdownOpacity: Double = 1.0
    @State private var countdownNumber: Int = 10
    @State private var animateCountdown = false
    
    var body: some View {
        ZStack {
            if cameraViewModel.isInPoseMatchingMode {
                // Camera view with pose matching
                ZStack {
                    CameraPreview(viewModel: cameraViewModel)
                        .ignoresSafeArea()
                        .onAppear {
                            // Ensure camera is running when view appears
                            if !cameraViewModel.session.isRunning {
                                cameraViewModel.startSession()
                            }
                        }
                    
                    // Reference image overlay
                    if let referenceImage = cameraViewModel.selectedReferenceImage {
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
                    
                    // Controls and status
                    VStack {
                        HStack {
                            // Camera switch button
                            Button(action: {
                                cameraViewModel.switchCamera()
                            }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .padding()
                            
                            Spacer()
                            
                            // Exit button
                            Button(action: {
                                cameraViewModel.exitPoseMatchingMode()
                                resetHold()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .padding()
                        }
                        
                        Spacer()
                        
                        // Status display
                        if !cameraViewModel.isPersonDetected {
                            Text("No person detected")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(15)
                        } else if cameraViewModel.currentPoseObservation == nil {
                            Text("Stand in frame for pose detection")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(15)
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
                            }
                        }
                    }
                    .padding(.bottom, 30)
                    // Countdown angka besar di tengah layar
                    if cameraViewModel.overallPoseMatchStatus && holdSeconds > 0 {
                        Text("\(countdownNumber)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(countdownOpacity)
                            .shadow(radius: 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: countdownOpacity)
                    }
                }
                .onAppear {
                    // Set up callback untuk notifikasi ketika postur cocok
                    cameraViewModel.onPoseMatched = {
                        // Tidak langsung next, gunakan timer hold
                    }
                }
                .onChange(of: cameraViewModel.overallPoseMatchStatus) { isMatching in
                    if isMatching {
                        startHold()
                    } else {
                        resetHold()
                    }
                }
                .onChange(of: cameraViewModel.isPersonDetected) { detected in
                    if !detected { resetHold() }
                }
                .onChange(of: cameraViewModel.currentPoseObservation) { obs in
                    if obs == nil { resetHold() }
                }
                .alert("Selesai!", isPresented: $showingFinishAlert) {
                    Button("Kembali ke Menu") {
                        cameraViewModel.exitPoseMatchingMode()
                        nextPoseIndex = 0
                        resetHold()
                    }
                } message: {
                    Text("Anda telah menyelesaikan semua postur!")
                }
            } else {
                // Pose selection view
                VStack {
                    Text("Select a Pose to Match")
                        .font(.title)
                        .padding()
                    
                    Button(action: {
                        showingPoseSelection = true
                    }) {
                        Text("Choose Pose")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    // Ensure camera is stopped when returning to pose selection
                    if cameraViewModel.session.isRunning {
                        cameraViewModel.stopSession()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPoseSelection) {
            PoseSelectionView(
                viewModel: poseSelectionViewModel,
                isPresented: $showingPoseSelection,
                onSelectPose: { pose in
                    cameraViewModel.setReferencePose(pose.image, name: pose.name)
                    nextPoseIndex = poseSelectionViewModel.postures.firstIndex(where: { $0.id == pose.id }) ?? 0
                    resetHold()
                }
            )
        }
    }
    
    private func startHold() {
        if holdTimer == nil {
            holdSeconds = 0
            countdownNumber = Int(holdDuration)
            countdownOpacity = 1.0
            animateCountdown = false
            holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                holdSeconds += 1.0
                if countdownNumber > 1 {
                    countdownNumber -= 1
                    withAnimation(.easeInOut(duration: 0.3)) {
                        countdownOpacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        countdownOpacity = 1.0
                    }
                } else {
                    holdTimer?.invalidate()
                    holdTimer = nil
                    holdSeconds = 0
                    countdownNumber = Int(holdDuration)
                    if nextPoseIndex + 1 >= poseSelectionViewModel.postures.count {
                        showingFinishAlert = true
                    } else {
                        moveToNextPose()
                    }
                }
            }
        }
    }
    private func resetHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdSeconds = 0
        countdownNumber = Int(holdDuration)
        countdownOpacity = 1.0
    }
    private func moveToNextPose() {
        let allPoses = poseSelectionViewModel.postures
        nextPoseIndex = (nextPoseIndex + 1) % allPoses.count
        
        if let nextPose = allPoses[safe: nextPoseIndex] {
            cameraViewModel.setReferencePose(nextPose.image, name: nextPose.name)
            resetHold()
        }
    }
}

// Extension untuk safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Preview for SwiftUI Canvas
#Preview {
    ContentView()
}
