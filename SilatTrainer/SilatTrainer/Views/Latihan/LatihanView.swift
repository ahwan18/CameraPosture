//
//  LatihanView.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import SwiftUI
import Vision

struct LatihanView: View {
    var navigate: (AppRoute) -> Void
    var close: () -> Void
    let poseData: [PoseData] = PoseLoader.loadPose()
    @Environment(\.dismiss) var dismiss
    @State private var showTutorial = false
    @State private var cameraVM = CameraViewModel()
    @State private var poseViewModel = PoseEstimationViewModel()

    @State private var wasAtOptimalDistance: Bool = true
    
    private func checkAndAnnounceDistance() {
        if !isAtOptimalDistance && wasAtOptimalDistance {
            VoiceHelper.shared.speak("Pastikan seluruh tubuh terlihat")
        }
        wasAtOptimalDistance = isAtOptimalDistance
    }

    // Add computed property to check joint visibility
    private var isAtOptimalDistance: Bool {
        let requiredJoints: [HumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        
        // Check if all required joints are detected with high confidence
        return requiredJoints.allSatisfy { joint in
            poseViewModel.detectedBodyParts[joint] != nil
        }
    }
    
    var body: some View {
            ZStack {
                CameraPreviewView(session: cameraVM.session)
                    .ignoresSafeArea()
                
                PoseOverlayView(
                    bodyParts: poseViewModel.detectedBodyParts,
                    connections: poseViewModel.bodyConnections
                )
                
                VStack {
                    HStack {
                        Button(action: {
                            showTutorial = true
                        }) {
                            Image(systemName: "info.circle")
                                .padding(.leading, 37)
                        }
                    .fullScreenCover(isPresented: $showTutorial) {
                        TutorialView(navigate: navigate)
                    }
                        
                        Spacer()
                        
                        Button(action: {
                            close()
                        }) {
                            Image(systemName: "x.circle")
                                .padding(.trailing, 37)
                        }
                        
                    }
                    .font(.system(size: 32.25, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.vertical, 4)
                    
                    Text("Jurus 1")
                        .font(.system(size: 32, weight: .bold))
                    
                    if let firstIndex = poseData.firstIndex(where: { _ in true }),
                       let lastIndex = poseData.indices.last {
                        let startLabel = "A\(firstIndex + 1)"
                        let endLabel = "A\(lastIndex + 1)"
                        
                        Text("\(startLabel) / \(endLabel)")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.gray.opacity(0.14))
                            )
                    }
                    
                    Spacer()
                    
                    // Add distance indicator
                    HStack {
                        Image(systemName: isAtOptimalDistance ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(isAtOptimalDistance ? .green : .orange)
                        Text(isAtOptimalDistance ? "Posisi Optimal" : "Sesuaikan Jarak")
                            .foregroundColor(isAtOptimalDistance ? .green : .orange)
                    }
                    .font(.system(size: 18, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.8))
                    )
                    
                    Text("Sesuaikan Posisi Anda di dalam Kotak")
                        .font(.system(size: 18, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 50)
                        .padding(.horizontal, 48)
                    
                    Button(action: {
                        navigate(.finish)
                    }) {
                        Text("Selesai")
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .task {
              await cameraVM.checkPermission()
              cameraVM.delegate = poseViewModel
            }.onChange(of: isAtOptimalDistance) { _, _ in
              checkAndAnnounceDistance()
            }
        }
    }
}

