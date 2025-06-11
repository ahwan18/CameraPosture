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
    
    // MARK: - State
    
    @State private var showingPosePreview = false
    @State private var previewCountdown = 3
    @State private var showSuccessAnimation = false
    @State private var previewTimer: Timer? // FIX: Properly manage preview timer
    
    var body: some View {
        ZStack {
            if showingPosePreview {
                // Pose Preview Screen
                posePreviewScreen
            } else {
                // Main Training Screen
                trainingScreen
            }
        }
        .onAppear {
            setupTraining()
        }
        .onDisappear {
            cleanupTraining()
        }
        .onReceive(cameraViewModel.$overallPoseMatchStatus) { isMatched in
            // CRITICAL BUG FIX: Connect pose matching to training
            trainingViewModel.updatePoseMatchStatus(isMatched)
        }
        .animation(.easeInOut(duration: 0.5), value: showingPosePreview)
    }
    
    // MARK: - Training Screen
    
    private var trainingScreen: some View {
        ZStack {
            // Camera preview
            CameraPreview(viewModel: cameraViewModel)
                .ignoresSafeArea()
            
            // Minimal overlay content
            VStack {
                // Top bar - minimal
                topBar
                
                Spacer()
                
                // Center content - only show what's needed at the moment
                centerContent
                
                Spacer()
                
                // Bottom content - minimal progress
                bottomContent
            }
        }
        .onReceive(trainingViewModel.$trainingSession) { session in
            if session?.isCompleted == true {
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }
        }
        .onReceive(cameraViewModel.$overallPoseMatchStatus) { isMatched in
            trainingViewModel.updatePoseMatchStatus(isMatched)
        }
        .alert("Training Complete!", isPresented: .constant(trainingViewModel.isCompleted)) {
            Button("Start Again") {
                trainingViewModel.restartTraining()
            }
            Button("Exit") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("🎉 Great job! You've completed all poses.")
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Exit button
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                    )
            }
            
            Spacer()
            
            // Minimal progress dots - only when training is active
            if trainingViewModel.isTrainingActive {
                HStack(spacing: 8) {
                    ForEach(0..<trainingViewModel.totalPoses, id: \.self) { index in
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(
                                index < trainingViewModel.currentPoseIndex ? .green :
                                index == trainingViewModel.currentPoseIndex ? .white :
                                .white.opacity(0.3)
                            )
                            .animation(.spring(response: 0.3), value: trainingViewModel.currentPoseIndex)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.3))
                )
            }
            
            Spacer()
            
            // Current pose reference - only when training is active
            if trainingViewModel.isTrainingActive, let currentPose = trainingViewModel.currentPose, let image = currentPose.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Center Content
    
    private var centerContent: some View {
        VStack(spacing: 20) {
            // Hold timer - only when needed
            if cameraViewModel.overallPoseMatchStatus && trainingViewModel.isHolding {
                holdTimerView
            }
            // Status message - minimal and contextual
            else {
                statusMessage
            }
        }
    }
    
    // MARK: - Hold Timer View
    
    private var holdTimerView: some View {
        VStack(spacing: 16) {
            // Circular progress timer
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: trainingViewModel.holdProgress)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .cyan]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: trainingViewModel.holdProgress)
                
                Text("\(Int(trainingViewModel.holdTimeRemaining) + 1)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Hold steady")
                .font(.headline)
                .foregroundColor(.white)
                .opacity(0.9)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.4))
        )
        .scaleEffect(showSuccessAnimation ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: showSuccessAnimation)
    }
    
    // MARK: - Status Message
    
    private var statusMessage: some View {
        Group {
            if !cameraViewModel.isPersonDetected {
                MinimalStatusView(
                    icon: "figure.stand",
                    message: "Step into frame",
                    color: .blue
                )
            } else if cameraViewModel.isStabilizingPosition {
                // PRIORITY: Show countdown when stabilizing (even if showPositioningBox is true)
                positioningStabilizationView
            } else if cameraViewModel.showPositioningBox && !cameraViewModel.isUserInPositioningBox {
                MinimalStatusView(
                    icon: "viewfinder",
                    message: "Position yourself in the frame",
                    color: .orange
                )
            } else if !trainingViewModel.isTrainingActive {
                MinimalStatusView(
                    icon: "checkmark.circle",
                    message: "Position confirmed! Preparing poses...",
                    color: .green
                )
            } else if !cameraViewModel.overallPoseMatchStatus {
                MinimalStatusView(
                    icon: "figure.yoga",
                    message: "Match the pose",
                    color: .white
                )
            }
        }
    }
    
    // MARK: - Positioning Stabilization View
    
    private var positioningStabilizationView: some View {
        VStack(spacing: 16) {
            // Circular progress timer for positioning
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: cameraViewModel.positioningProgress)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .cyan]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: cameraViewModel.positioningProgress)
                
                Text("\(max(1, Int(ceil(3.0 - cameraViewModel.positioningTimer))))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text("Stay in position")
                .font(.headline)
                .foregroundColor(.white)
                .opacity(0.9)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.4))
        )
    }
    
    // MARK: - Bottom Content
    
    private var bottomContent: some View {
        VStack(spacing: 12) {
            // Current pose name - only when training is active
            if trainingViewModel.isTrainingActive, let currentPose = trainingViewModel.currentPose {
                Text(currentPose.name)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                    )
            }
            
            // Match accuracy - only when user is trying to match
            if trainingViewModel.isTrainingActive &&
               cameraViewModel.isPersonDetected && 
               !cameraViewModel.showPositioningBox && 
               !cameraViewModel.overallPoseMatchStatus {
                Text("\(Int(cameraViewModel.poseMatchPercentage))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.2))
                    )
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Pose Preview Screen
    
    private var posePreviewScreen: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.9)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Pose name
                Text(trainingViewModel.currentPose?.name ?? "Unknown")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Large pose image
                if let currentPose = trainingViewModel.currentPose, let image = currentPose.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 280, maxHeight: 350)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                }
                
                // Countdown
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Text("\(previewCountdown)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupTraining() {
        print("🚀 Setting up training - initializing positioning mode")
        
        cameraViewModel.startSession()
        cameraViewModel.sequentialTrainingDelegate = trainingViewModel
        
        // Initialize positioning mode first
        cameraViewModel.showPositioningBox = true
        cameraViewModel.canStartPoseMatching = false
        cameraViewModel.isInPoseMatchingMode = false
        
        trainingViewModel.onPoseChanged = { posture in
            showPosePreview(for: posture)
        }
        
        trainingViewModel.onTrainingCompleted = {
            print("SequentialPoseView: Training completed")
        }
        
        trainingViewModel.onPositioningLost = {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        }
        
        print("📦 Positioning mode enabled - ShowBox: \(cameraViewModel.showPositioningBox)")
        
        // Don't start training immediately - wait for proper positioning first
        // Training will be started automatically when positioning is complete
    }
    
    private func cleanupTraining() {
        // CRITICAL BUG FIX: Cleanup all timers and resources
        previewTimer?.invalidate()
        previewTimer = nil
        cameraViewModel.exitPoseMatchingMode()
        trainingViewModel.stopTraining()
    }
    
    private func showPosePreview(for posture: Posture) {
        // CRITICAL BUG FIX: Cleanup existing timer before creating new one
        previewTimer?.invalidate()
        
        showingPosePreview = true
        previewCountdown = 3
        
        previewTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            previewCountdown -= 1
            
            if previewCountdown <= 0 {
                timer.invalidate()
                self.previewTimer = nil
                showingPosePreview = false
                
                if let image = posture.image {
                    cameraViewModel.setReferencePose(image, name: posture.name, enableContinuousMonitoring: true)
                }
            }
        }
    }
}

// MARK: - Minimal Status View Component

struct MinimalStatusView: View {
    let icon: String
    let message: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
        )
    }
}

 