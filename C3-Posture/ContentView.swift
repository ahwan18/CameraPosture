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
    @State private var showingSequentialTraining = false
    
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
                }
            } else {
                // Pose selection view
                VStack(spacing: 30) {
                    Text("Posture Training")
                        .font(.largeTitle)
                        .bold()
                        .padding()
                    
                    VStack(spacing: 20) {
                        Button(action: {
                            showingPoseSelection = true
                        }) {
                            VStack {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                
                                Text("Single Pose Practice")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Choose and practice one pose")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            showingSequentialTraining = true
                        }) {
                            VStack {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                
                                Text("Sequential Training")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Practice all poses in sequence")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal)
                    }
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
                }
            )
        }
        .fullScreenCover(isPresented: $showingSequentialTraining) {
            SequentialPoseView()
        }
    }
}

// Preview for SwiftUI Canvas
#Preview {
    ContentView()
}
