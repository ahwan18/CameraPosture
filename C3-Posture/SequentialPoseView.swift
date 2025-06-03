import SwiftUI
import AVFoundation
import Combine

// MARK: - Sequential Pose Training View
struct SequentialPoseView: View {
    @StateObject private var sequentialPoseManager = SequentialPoseManager()
    @StateObject private var cameraViewModel = CameraViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(viewModel: cameraViewModel)
                .ignoresSafeArea()
                .onAppear {
                    cameraViewModel.startSession()
                    sequentialPoseManager.startSequentialTraining { name, image in
                        cameraViewModel.setReferencePose(image, name: name)
                    }
                }
                .onDisappear {
                    cameraViewModel.stopSession()
                    sequentialPoseManager.stopTraining()
                }
            
            // Current pose overlay (top right)
            if let currentPose = sequentialPoseManager.currentPose {
                VStack {
                    HStack {
                        Spacer()
                        VStack {
                            Image(uiImage: currentPose.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(12)
                            
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
                        Text("Pose \(sequentialPoseManager.currentPoseIndex + 1) of \(sequentialPoseManager.totalPoses)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ProgressView(value: Double(sequentialPoseManager.currentPoseIndex), total: Double(sequentialPoseManager.totalPoses))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: 200)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    
                    // Hold timer (only show when pose is matched)
                    if cameraViewModel.overallPoseMatchStatus && sequentialPoseManager.isHolding {
                        VStack(spacing: 8) {
                            Text("Hold this pose!")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.green)
                            
                            Text("\(Int(sequentialPoseManager.holdTimeRemaining))s")
                                .font(.largeTitle)
                                .bold()
                                .foregroundColor(.green)
                            
                            ProgressView(value: sequentialPoseManager.holdProgress)
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
                    if sequentialPoseManager.isCompleted {
                        VStack {
                            Text("🎉 All poses completed!")
                                .font(.title)
                                .bold()
                                .foregroundColor(.green)
                            
                            Text("Great job!")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Button("Start Again") {
                                sequentialPoseManager.restartTraining { name, image in
                                    cameraViewModel.setReferencePose(image, name: name)
                                }
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
        .onReceive(sequentialPoseManager.$isCompleted) { completed in
            if completed {
                // Optional: Add haptic feedback or sound
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            }
        }
        .onReceive(cameraViewModel.$overallPoseMatchStatus) { isMatched in
            sequentialPoseManager.updatePoseMatchStatus(isMatched)
        }
    }
}

// MARK: - Sequential Pose Manager
class SequentialPoseManager: ObservableObject {
    @Published var currentPose: (name: String, image: UIImage)?
    @Published var currentPoseIndex = 0
    @Published var totalPoses = 0
    @Published var isHolding = false
    @Published var holdTimeRemaining: Double = 5.0
    @Published var holdProgress: Double = 0.0
    @Published var isCompleted = false
    
    private var poses: [(name: String, image: UIImage)] = []
    private var holdTimer: Timer?
    private var onPoseChanged: (String, UIImage) -> Void = { _, _ in }
    private let requiredHoldTime: Double = 5.0
    
    init() {
        loadAllPoses()
    }
    
    private func loadAllPoses() {
        let posturesManager = PosturesManager.shared
        let poseInfos = posturesManager.getAllPostures()
        
        poses = poseInfos.compactMap { poseInfo in
            guard let image = posturesManager.loadPostureImage(named: poseInfo.filename) else {
                return nil
            }
            return (name: poseInfo.name, image: image)
        }
        
        totalPoses = poses.count
        print("Loaded \(totalPoses) poses for sequential training")
    }
    
    func startSequentialTraining(onPoseChanged: @escaping (String, UIImage) -> Void) {
        self.onPoseChanged = onPoseChanged
        currentPoseIndex = 0
        isCompleted = false
        setCurrentPose()
    }
    
    func restartTraining(onPoseChanged: @escaping (String, UIImage) -> Void) {
        stopTraining()
        startSequentialTraining(onPoseChanged: onPoseChanged)
    }
    
    func stopTraining() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdTimeRemaining = requiredHoldTime
        holdProgress = 0.0
    }
    
    private func setCurrentPose() {
        guard currentPoseIndex < poses.count else {
            // All poses completed
            isCompleted = true
            currentPose = nil
            return
        }
        
        let pose = poses[currentPoseIndex]
        currentPose = pose
        onPoseChanged(pose.name, pose.image)
        resetHoldTimer()
    }
    
    func updatePoseMatchStatus(_ isMatched: Bool) {
        if isMatched && !isHolding && !isCompleted {
            // User matched the pose and we're not already holding - start the timer
            startHoldTimer()
        } else if !isMatched && isHolding {
            // User lost the pose while holding - reset the timer completely
            resetHoldTimer()
            print("Pose match lost - timer reset!")
        } else if isMatched && isHolding {
            // User is still matching and holding - timer continues
            // No action needed, timer keeps running
        } else if !isMatched && !isHolding {
            // User is not matching and not holding - ensure timer stays reset
            resetHoldTimer()
        }
    }
    
    private func startHoldTimer() {
        // Stop any existing timer first
        holdTimer?.invalidate()
        
        isHolding = true
        holdTimeRemaining = requiredHoldTime
        holdProgress = 0.0
        
        print("Starting hold timer for \(requiredHoldTime) seconds")
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.holdTimeRemaining -= 0.1
            self.holdProgress = 1.0 - (self.holdTimeRemaining / self.requiredHoldTime)
            
            if self.holdTimeRemaining <= 0 {
                timer.invalidate()
                print("Hold timer completed successfully!")
                self.completeCurrentPose()
            }
        }
    }
    
    private func resetHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdTimeRemaining = requiredHoldTime
        holdProgress = 0.0
        print("Hold timer reset")
    }
    
    private func completeCurrentPose() {
        isHolding = false
        holdTimeRemaining = requiredHoldTime
        holdProgress = 0.0
        
        // Move to next pose
        currentPoseIndex += 1
        
        // Delay before showing next pose
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.setCurrentPose()
        }
    }
} 