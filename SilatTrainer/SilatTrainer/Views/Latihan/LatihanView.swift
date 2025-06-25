import SwiftUI
import Vision
import UIKit
import SwiftData

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
    
    
    // SwiftData model context
    @Environment(\.modelContext) private var modelContext
    
    // Alert state
    @State private var showExitConfirmation = false
    
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
        let latihanViewModel = LatihanViewModel(poseViewModel: poseVM)
        
        // Set up navigation callback to finish view - pastikan ini berjalan di main thread dan hanya sekali
        latihanViewModel.navigateToFinish = {
            print("LatihanView: navigateToFinish dipanggil, akan navigasi ke .finish")
            
            // Pastikan navigasi pada main thread
            if Thread.isMainThread {
                print("Sudah di main thread, navigasi langsung")
                navigate(.finish)
            } else {
                print("Bukan di main thread, dispatch ke main")
                DispatchQueue.main.async {
                    navigate(.finish)
                }
            }
        }
        
        _latihanVM = StateObject(wrappedValue: latihanViewModel)
    }
    
    var body: some View {
        ZStack {
            if cameraVM.permissionStatus == .denied {
                PermissionDeniedView()
            } else {
                CameraPreviewView(session: cameraVM.session)
                    .ignoresSafeArea()
                
                // Overlay that shows detected body parts, connections, and guidance elements
                PoseOverlayView(
                    bodyParts: poseViewModel.detectedBodyParts,
                    connections: poseViewModel.bodyConnections,
                    targetPose: latihanVM.currentTargetPose,
                    showGuideArrows: latihanVM.isAtOptimalDistance && !latihanVM.isPoseMatched && !latihanVM.showPoseTransition,
                    showFittingBox: latihanVM.phase != .evaluating,
                    isUserPositioned: latihanVM.isUserPositioned,
                    isPositioningPhase: latihanVM.phase == .positioning
                )
                
                VStack {
                    // UI changes based on the current training phase
                    
                    HStack {
                        Button(action: {
                            // Show confirmation alert instead of closing immediately
                            showExitConfirmation = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24, weight: .semibold))
                                Text("Kembali")
                                    .font(.system(size: 24, weight: .semibold))
                            }
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 2, x: 0, y: 2)
                        }
                        
                        Spacer()
                        
                        // Title on the right - consistent across all phases
                        Text("Jurus 1")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.black)
                            .shadow(color: .white, radius: 2, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
                    
                    // Session timer and pose name in horizontal layout with matching styles - consistent across all phases
                    HStack {
                        // Timer container with brown background
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("silatB"))
                                .frame(width: 140, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black, lineWidth: 3)
                                )
                            
                            Text(latihanVM.sessionElapsedTime)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Pose name container with matching style
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("silatB"))
                                .frame(width: 140, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black, lineWidth: 3)
                                )
                            
                            Text(latihanVM.poseName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(latihanVM.showPoseTransition ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: latihanVM.showPoseTransition)
                    
                    Spacer()
                    
                    if latihanVM.phase == .evaluating && !latihanVM.showPoseTransition {                        
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
                            
                            // Control buttons always visible
                            HStack {
                                // Mute button on the left side
                                Button(action: {
                                    latihanVM.toggleMute()
                                }) {
                                    Image(systemName: latihanVM.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(22)
                                }
                                
                                Spacer()
                                
                                // Play/Pause button on the right side
                                Button(action: {
                                    latihanVM.togglePause()
                                }) {
                                    Image(systemName: latihanVM.isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(22)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            
                            // Only show pose matching guidance when at optimal distance and not transitioning
                            if latihanVM.isAtOptimalDistance && !latihanVM.showPoseTransition {
                                // Hold timer and progress when pose is matched
                                if latihanVM.isPoseMatched {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 15)
                                                .fill(Color.black.opacity(0.8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 15)
                                                        .stroke(Color.white, lineWidth: 2)
                                                )
                                                .frame(width: 200, height: 120)
                                            
                                            VStack(spacing: 0) {
                                                Text("Tahan Posisi")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .padding(.top, 10)
                                                
                                                Text("\(latihanVM.countdownValue)")
                                                    .font(.system(size: 60, weight: .bold))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        
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
                    }
                }
                
                if latihanVM.showFirstPoseView {
                    PosePertamaView()
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .zIndex(999)
                    .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
                    .edgesIgnoringSafeArea(.all)
                }
                
                // Pose transition overlay - shown between poses
                if latihanVM.showPoseTransition {
                    PoseTransitionView(
                        poseNumber: latihanVM.currentPoseIndex + 2,
                        targetPose: latihanVM.nextTargetPose,
                        sessionElapsedTime: latihanVM.sessionElapsedTime
                    )
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .zIndex(999)
                    .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
                    .edgesIgnoringSafeArea(.all)
                }
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
            
            // Save training data when the view is disappearing
            latihanVM.saveTrainingSession(to: modelContext)
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
        .alert("Akhiri Latihan?", isPresented: $showExitConfirmation) {
            Button("Batal", role: .cancel) { }
            Button("Akhiri", role: .destructive) {
                // Mark remaining poses as incorrect before closing
                latihanVM.markRemainingPosesAsIncorrect()
                latihanVM.saveTrainingSession(to: modelContext)
                close()
            }
        } message: {
            Text("Jika kamu keluar sekarang, sesi latihan akan diakhiri dan semua gerakan yang belum selesai akan dianggap salah.")
        }
    }
    
    /// `PoseTransitionView` displays information about the next pose during transitions
    /// It shows a fullscreen overlay with the pose number, image, and countdown
    struct PoseTransitionView: View {
        // The number of the upcoming pose
        let poseNumber: Int
        // Data for the upcoming pose (optional)
        let targetPose: PoseData?
        // Current session elapsed time
        let sessionElapsedTime: String
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Solid background (not transparent)
                    Color.silatD
                        .ignoresSafeArea()
                    
                    VStack {
                        // Header spacing for consistency with main view
                        HStack {
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 100)
                        
                        
                        VStack(spacing: 30) {
                            // Transition header
                            Text("Gerakan Berikutnya")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Pose identifier
                            Text("A\(poseNumber)")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            // Pose reference image (if available)
                            if targetPose != nil {
                                Image("A\(poseNumber)")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 600)
                                    .padding(.horizontal, 30)
                                    .padding(.bottom, 70)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea(.all)
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    struct PosePertamaView: View {
        // The number of the upcoming pose
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Solid background (not transparent)
                    Color.silatD
                        .ignoresSafeArea()
                    
                    VStack {
                        // Header spacing for consistency with main view
                        HStack {
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 100)
                        
                        
                        VStack(spacing: 30) {
                            // Transition header
                            Text("Gerakan Pertama")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Pose identifier
                            Text("A1")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            // Pose reference image (if available)
                                Image("A1")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 600)
                                    .padding(.horizontal, 30)
                                    .padding(.bottom, 70)
                        }
                        
                        Spacer()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea(.all)
            .edgesIgnoringSafeArea(.all)
        }
    }
}
