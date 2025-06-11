import SwiftUI
import AVFoundation
import Combine

// MARK: - Sequential Pose Training View
struct SequentialPoseView: View {
    
    // MARK: - ViewModels
    
    @StateObject private var trainingViewModel = SequentialTrainingViewModel()
    @StateObject private var cameraViewModel = CameraViewModel()
    
    // MARK: - Environment
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(viewModel: cameraViewModel)
                .ignoresSafeArea()
                .onAppear {
                    setupTraining()
                }
                .onDisappear {
                    cleanupTraining()
                }
            
            // Current pose overlay (top right)
            if let currentPose = trainingViewModel.currentPose {
                VStack {
                    HStack {
                        Spacer()
                        VStack {
                            if let image = currentPose.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(12)
                            }
                            
                            Text(currentPose.name)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            
            // Progress and controls
            VStack {
                // Top controls
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                    
                    Button(action: {
                        cameraViewModel.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                // Bottom status and progress
                VStack(spacing: 16) {
                    // Progress indicator
                    VStack(spacing: 8) {
                        Text("Pose \(trainingViewModel.currentPoseIndex + 1) of \(trainingViewModel.totalPoses)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ProgressView(value: Double(trainingViewModel.currentPoseIndex), total: Double(trainingViewModel.totalPoses))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: 200)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    
                    // Hold timer (only show when pose is matched)
                    if cameraViewModel.overallPoseMatchStatus && trainingViewModel.isHolding {
                        VStack(spacing: 8) {
                            Text("Hold this pose!")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.green)
                            
                            Text("\(Int(trainingViewModel.holdTimeRemaining))s")
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(.green)
                            
                            ProgressView(value: trainingViewModel.holdProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                .frame(width: 150)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(15)
                    } else if !cameraViewModel.isPersonDetected {
                        Text("Step into frame")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(15)
                    } else if !cameraViewModel.overallPoseMatchStatus {
                        VStack {
                            Text("Match the pose")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.yellow)
                            
                            Text("Accuracy: \(Int(cameraViewModel.poseMatchPercentage))%")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(15)
                    }
                    
                    // Completion message
                    if trainingViewModel.isCompleted {
                        VStack {
                            Text("🎉 All poses completed!")
                                .font(.title)
                                .bold()
                                .foregroundColor(.green)
                            
                            Text("Great job!")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Button("Start Again") {
                                trainingViewModel.restartTraining()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .padding()
                        .background(Color.black.opacity(0.9))
                        .cornerRadius(20)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onReceive(trainingViewModel.$trainingSession) { session in
            if session?.isCompleted == true {
                // Optional: Add haptic feedback or sound
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }
        }
        .onReceive(cameraViewModel.$overallPoseMatchStatus) { isMatched in
            trainingViewModel.updatePoseMatchStatus(isMatched)
        }
        .alert("Training Error", isPresented: .constant(trainingViewModel.errorMessage != nil)) {
            Button("OK") {
                trainingViewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = trainingViewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupTraining() {
        cameraViewModel.startSession()
        
        // Set up training callbacks
        trainingViewModel.onPoseChanged = { posture in
            if let image = posture.image {
                cameraViewModel.setReferencePose(image, name: posture.name)
            }
        }
        
        trainingViewModel.onTrainingCompleted = {
            // Handle training completion
            print("SequentialPoseView: Training completed")
        }
        
        // Start the training
        trainingViewModel.startTraining()
    }
    
    private func cleanupTraining() {
        cameraViewModel.stopSession()
        trainingViewModel.stopTraining()
    }
}

 