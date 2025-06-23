import SwiftUI
import Vision
import UIKit

/// `LatihanView` is the main training view that handles pose detection, matching, and user guidance
/// This view integrates camera feed, pose overlay, and interactive training elements
struct LatihanView: View {
    // Navigation closures for app routing
    var navigate: (AppRoute) -> Void
    var close: () -> Void
    
    // View models that manage different aspects of the training session
    @StateObject private var latihanVM: LatihanViewModel           // Manages the training flow and session state
    @StateObject private var cameraVM = CameraViewModel()          // Handles camera access and configuration
    @StateObject private var poseViewModel: PoseEstimationViewModel // Processes camera feed for pose detection
    
    // State for showing the tutorial overlay
    @State private var showTutorial = false

    /// Initializes the view with navigation handlers and sets up the view models
    /// - Parameters:
    ///   - navigate: Closure for navigating to other app routes
    ///   - close: Closure for closing/exiting the training view
    init(navigate: @escaping (AppRoute) -> Void, close: @escaping () -> Void) {
        self.navigate = navigate
        self.close = close
        
        // Initialize the pose estimation view model first
        let poseVM = PoseEstimationViewModel()
        _poseViewModel = StateObject(wrappedValue: poseVM)
        
        // Pass the pose view model to the training view model for coordination
        _latihanVM = StateObject(wrappedValue: LatihanViewModel(poseViewModel: poseVM))
    }
    
    var body: some View {
        ZStack {
            // Camera preview layer that shows the camera feed
            CameraPreviewView(session: cameraVM.session)
                .ignoresSafeArea()
            
            // Overlay that shows detected body parts, connections, and guidance elements
            PoseOverlayView(
                bodyParts: poseViewModel.detectedBodyParts,
                connections: poseViewModel.bodyConnections,
                targetPose: latihanVM.currentTargetPose,
                showGuideArrows: latihanVM.isAtOptimalDistance && !latihanVM.isPoseMatched && !latihanVM.showPoseTransition,
                showFittingBox: latihanVM.phase != .evaluating
            )
            
            VStack {
                // UI changes based on the current training phase
                if latihanVM.phase == .evaluating {
                    // Top navigation bar with info and close buttons
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
                    
                    // Display current training set ("Jurus") title
                    Text("Jurus 1")
                        .font(.system(size: 32, weight: .bold))
                    
                    // Display current pose name with styled background
                    Text("\(latihanVM.poseName)")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.5))
                        )
                        .overlay(
                           RoundedRectangle(cornerRadius: 10)
                              .stroke(Color.black, lineWidth:1)
                        )
                    
                    Spacer()
                    
                    // Feedback and guidance panel
                    VStack(spacing: 10) {
                        // Distance guidance - informs user if they're at optimal distance
                        HStack {
                            Image(systemName: latihanVM.isAtOptimalDistance ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(latihanVM.isAtOptimalDistance ? .green : .orange)
                            Text(latihanVM.isAtOptimalDistance ? "Posisi Optimal" : "Sesuaikan Jarak")
                                .foregroundColor(latihanVM.isAtOptimalDistance ? .green : .orange)
                        }
                        .font(.system(size: 18, weight: .medium))
                        
                        // Only show pose matching guidance when at optimal distance and not transitioning
                        if latihanVM.isAtOptimalDistance && !latihanVM.showPoseTransition {
                            // Pose matching status
                            HStack {
                                Image(systemName: latihanVM.isPoseMatched ? "checkmark.circle.fill" : "target")
                                    .foregroundColor(latihanVM.isPoseMatched ? .green : .blue)
                                Text(latihanVM.isPoseMatched ? "Pose Cocok - Tahan!" : "Sesuaikan Pose")
                                    .foregroundColor(latihanVM.isPoseMatched ? .green : .blue)
                            }
                            .font(.system(size: 16, weight: .medium))
                            
                            // Hold timer and progress when pose is matched
                            if latihanVM.isPoseMatched {
                                VStack(spacing: 8) {
                                    Text("\(latihanVM.countdownValue)")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.green)
                                    
                                    // Progress bar for hold duration
                                    ProgressView(value: latihanVM.holdProgress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                        .frame(width: 200)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.8))
                    )
                    
                    // Button to finish or skip the current training
                    Button(action: {
                        navigate(.finish)
                    }) {
                        Text(latihanVM.showCompletionMessage ? "Selesai" : "Lewati")
                    }
                } else {
                    Spacer()
                    // Positioning phase UI - guides the user to position correctly in frame
                    if latihanVM.phase == .positioning {
                        Text("Posisikan Diri Anda")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                        
                        Text(latihanVM.isUserPositioned ? "Bagus! Tahan Posisi" : "Pastikan seluruh tubuh berada di dalam kotak")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(latihanVM.isUserPositioned ? .green : .yellow)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                            .shadow(radius: 3)
                    }
                    
                    // Countdown phase UI - shows large countdown numbers
                    if latihanVM.phase == .countdown {
                        Text("\(latihanVM.positioningCountdownValue)")
                            .font(.system(size: 120, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                            .transition(.opacity.combined(with: .scale))
                    }
                    Spacer()
                    Spacer()
                }
            }
            .padding(.vertical, 30)
            .animation(.easeInOut, value: latihanVM.phase)
            .opacity(latihanVM.showPoseTransition ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: latihanVM.showPoseTransition)
            
            // Pose transition overlay - shown between poses
            if latihanVM.showPoseTransition {
                let poseTransitionView = PoseTransitionView(
                    poseNumber: latihanVM.currentPoseIndex + 2,
                    targetPose: latihanVM.nextTargetPose
                )
                poseTransitionView
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Prevent screen from turning off during training
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Revert screen timeout settings and clean up resources
            UIApplication.shared.isIdleTimerDisabled = false
            latihanVM.cleanup()
        }
        .task {
            // Initialize camera when view appears
            await cameraVM.checkPermission()
            cameraVM.delegate = poseViewModel
        }
        .onChange(of: poseViewModel.detectedBodyParts) { _, _ in
            // Update training state whenever new body parts are detected
            latihanVM.update()
        }
    }
}

/// `PoseTransitionView` displays information about the next pose during transitions
/// It shows a fullscreen overlay with the pose number, image, and countdown
struct PoseTransitionView: View {
    // The number of the upcoming pose
    let poseNumber: Int
    // Data for the upcoming pose (optional)
    let targetPose: PoseData?
    
    var body: some View {
        ZStack {
            // Dimmed background for focus
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Transition header
                Text("Gerakan Berikutnya")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                // Pose identifier
                Text("A\(poseNumber)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.yellow)
                
                // Pose reference image (if available)
                if targetPose != nil {
                    Image("silat_a")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 40)
                }
                
                // Countdown text
                Text("Siap dalam...")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                // Countdown value
                Text("2")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.green)
            }
        }
    }
} 
