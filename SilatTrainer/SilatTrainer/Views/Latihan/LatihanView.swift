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
    @State private var trainingVM = TrainingViewModel()
    
    // State untuk mengontrol flow aplikasi
    @State private var trainingState: TrainingState = .positioning
    @State private var positioningTimer: Timer?
    @State private var positionStableCount: Int = 0
    
    // DEBUG STATES - untuk tracking masalah
    @State private var debugFeedbacks: [PoseComparison.Feedback] = []
    @State private var debugMessages: [String] = []
    @State private var lastComparisonTime: Date = Date()
    @State private var comparisonCount: Int = 0
    
    enum TrainingState {
        case positioning
        case ready
        case training
        case completed
    }
    
    private let requiredStableFrames = 30
    private let positionCheckInterval = 0.1
    
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugMessages.append("[\(timestamp)] \(message)")
        if debugMessages.count > 10 {
            debugMessages.removeFirst()
        }
        print("🔍 DEBUG: \(message)")
    }
    
    private func checkAndAnnounceDistance() {
        if trainingState == .positioning && !isAtOptimalDistance {
            VoiceHelper.shared.speak("Pastikan seluruh tubuh terlihat")
            addDebugMessage("Voice: Pastikan seluruh tubuh terlihat")
        }
    }
    
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
        
        let detectedJoints = requiredJoints.filter { joint in
            poseViewModel.detectedBodyParts[joint] != nil
        }
        
        addDebugMessage("Detected joints: \(detectedJoints.count)/\(requiredJoints.count)")
        
        return requiredJoints.allSatisfy { joint in
            poseViewModel.detectedBodyParts[joint] != nil
        }
    }
    
    private func handlePositioning() {
        if isAtOptimalDistance {
            positionStableCount += 1
            addDebugMessage("Position stable count: \(positionStableCount)/\(requiredStableFrames)")
            
            if positionStableCount >= requiredStableFrames {
                withAnimation {
                    trainingState = .ready
                }
                addDebugMessage("STATE CHANGED: positioning -> ready")
                VoiceHelper.shared.speak("Posisi optimal! Siap memulai latihan")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    startTraining()
                }
            }
        } else {
            if positionStableCount > 0 {
                addDebugMessage("Position lost, resetting counter")
            }
            positionStableCount = 0
        }
    }
    
    private func startTraining() {
        withAnimation {
            trainingState = .training
        }
        addDebugMessage("STATE CHANGED: ready -> training")
        addDebugMessage("Training started - pose comparison should begin")
        VoiceHelper.shared.speak("Mulai latihan!")
    }
    
    // ENHANCED POSE COMPARISON dengan debug extensive
    private func handlePoseComparison() {
        guard trainingState == .training else {
            addDebugMessage("❌ handlePoseComparison called but not in training state: \(trainingState)")
            return
        }
        
        comparisonCount += 1
        lastComparisonTime = Date()
        
        addDebugMessage("🔄 Pose comparison #\(comparisonCount) started")
        
        // Check if we have reference pose
        guard trainingVM.currentPoseIndex < trainingVM.poses.count else {
            addDebugMessage("❌ No reference pose available. Index: \(trainingVM.currentPoseIndex), Count: \(trainingVM.poses.count)")
            return
        }
        
        let referencePose = trainingVM.poses[trainingVM.currentPoseIndex].joints
        addDebugMessage("📋 Reference pose joints count: \(referencePose.count)")
        addDebugMessage("📋 Current pose joints count: \(poseViewModel.detectedBodyParts.count)")
        
        // Log some joint positions for debugging
        if let leftShoulder = poseViewModel.detectedBodyParts[.leftShoulder] {
            addDebugMessage("📍 Current left shoulder: \(leftShoulder)")
        }
//        if let refLeftShoulder = referencePose[.leftShoulder] {
//            addDebugMessage("📍 Reference left shoulder: \(refLeftShoulder)")
//        }
        
        let comparison = PoseComparison(
            currentPose: poseViewModel.detectedBodyParts,
            referencePose: referencePose
        )
        
        let feedbacks = comparison.compare()
        
        addDebugMessage("🎯 Comparison result: \(feedbacks.count) feedbacks")
        
        // Log each feedback in detail
        for (index, feedback) in feedbacks.enumerated() {
            let feedbackDetail = "Feedback \(index): Joint=\(feedback.joint.rawValue), Direction=\(feedback.direction), Message='\(feedback.message)'"
            addDebugMessage("📢 \(feedbackDetail)")
        }
        
        // Update debug state
        debugFeedbacks = feedbacks
        
        // Update TrainingViewModel
        trainingVM.currentFeedbacks = feedbacks
        addDebugMessage("✅ Updated trainingVM.currentFeedbacks with \(feedbacks.count) items")
        
        if feedbacks.isEmpty {
            addDebugMessage("✅ Perfect pose! Starting hold timer")
            if !trainingVM.isHolding {
                trainingVM.startHoldTimer()
            }
        } else {
            addDebugMessage("⚠️ Pose needs correction, stopping hold timer")
            trainingVM.resetHoldTimer()
            
            // Audio feedback for first issue
            if let feedback = feedbacks.first {
                AudioFeedbackManager.shared.addFeedback(feedback.message)
                addDebugMessage("🔊 Audio feedback: \(feedback.message)")
            }
        }
    }
    
    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraVM.session)
                .ignoresSafeArea()
            
            // ENHANCED OVERLAY dengan debug info
            PoseOverlayView(
                bodyParts: poseViewModel.detectedBodyParts,
                connections: poseViewModel.bodyConnections,
                feedbacks: trainingState == .training ? debugFeedbacks : [],
                holdProgress: trainingState == .training ? trainingVM.holdProgress : 0
            )
            
            // DEBUG OVERLAY - tampilkan info debug
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🔍 DEBUG INFO")
                            .font(.caption)
                            .foregroundColor(.white)
                            .bold()
                        
                        Text("State: \(String(describing: trainingState))")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        
                        Text("Feedbacks: \(debugFeedbacks.count)")
                            .font(.caption2)
                            .foregroundColor(debugFeedbacks.isEmpty ? .red : .green)
                        
                        Text("Comparisons: \(comparisonCount)")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                        
                        Text("Pose Index: \(trainingVM.currentPoseIndex)")
                            .font(.caption2)
                            .foregroundColor(.white)
                        
                        Text("Is Holding: \(trainingVM.isHolding)")
                            .font(.caption2)
                            .foregroundColor(trainingVM.isHolding ? .green : .gray)
                        
                        // Show recent debug messages
                        ForEach(Array(debugMessages.suffix(3).enumerated()), id: \.offset) { _, message in
                            Text(message)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        // Show current feedbacks
                        ForEach(Array(debugFeedbacks.prefix(2).enumerated()), id: \.offset) { index, feedback in
                            Text("Arrow \(index): \(feedback.joint.rawValue) → \(feedback.direction)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .frame(maxWidth: 200)
                    
                    Spacer()
                }
                Spacer()
            }
            
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
                
                Text(titleForCurrentState)
                    .font(.system(size: 32, weight: .bold))
                    .background(Color.white.opacity(0.8))
                
                if let firstIndex = poseData.firstIndex(where: { _ in true }),
                   let lastIndex = poseData.indices.last {
                    let startLabel = "A\(firstIndex + 1)"
                    let endLabel = "A\(lastIndex + 1)"
                    
                    Text("A\(trainingVM.currentPoseIndex + 1) / A7")
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
                
                VStack {
                    switch trainingState {
                    case .positioning:
                        positioningContent
                    case .ready:
                        readyContent
                    case .training:
                        trainingContent
                    case .completed:
                        completedContent
                    }
                }
                
                instructionText
                
                if trainingState == .ready {
                    Button(action: startTraining) {
                        Text("Mulai Sekarang")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 20)
                }
                
                // DEBUG BUTTON - untuk test manual
                if trainingState == .training {
                    Button(action: {
                        // Create test feedback
                        let testFeedback = PoseComparison.Feedback(
                            joint: .leftShoulder,
                            direction: .up,
                            message: "Test feedback"
                        )
                        debugFeedbacks = [testFeedback]
                        addDebugMessage("Manual test feedback created")
                    }) {
                        Text("Test Arrow")
                            .font(.caption)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                    }
                }
                
                Button(action: {
                    navigate(.finish)
                }) {
                    Text("Selesai")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            addDebugMessage("LatihanView appeared")
            trainingVM.onComplete = {
                trainingState = .completed
                navigate(.finish)
            }
        }
        .onChange(of: poseViewModel.detectedBodyParts) { newPose in
            switch trainingState {
            case .positioning:
                handlePositioning()
            case .training:
                handlePoseComparison()
            default:
                break
            }
        }
        .onChange(of: isAtOptimalDistance) {
            if trainingState == .positioning {
                checkAndAnnounceDistance()
            }
        }
        .task {
            await cameraVM.checkPermission()
            cameraVM.delegate = poseViewModel
            startPositioningTimer()
        }
        .onDisappear {
            positioningTimer?.invalidate()
        }
    }
    
    // ... rest of the computed properties remain the same
    private var titleForCurrentState: String {
        switch trainingState {
        case .positioning: return "Atur Posisi"
        case .ready: return "Siap Latihan"
        case .training: return "Jurus 1"
        case .completed: return "Selesai"
        }
    }
    
    private var positioningContent: some View {
        VStack {
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
            
            if isAtOptimalDistance {
                VStack {
                    Text("Pertahankan posisi...")
                    ProgressView(value: Double(positionStableCount), total: Double(requiredStableFrames))
                        .frame(width: 200)
                }
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
            }
        }
    }
    
    private var readyContent: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            Text("Posisi Optimal!")
                .font(.title)
                .foregroundColor(.green)
            Text("Siap memulai latihan")
                .font(.title2)
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(15)
    }
    
    private var trainingContent: some View {
        VStack {
            Text("Jurus \(trainingVM.currentPoseIndex + 1)")
                .font(.title)
                .background(Color.white.opacity(0.8))
            
            if trainingVM.isHolding {
                Text("Tahan pose...")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var completedContent: some View {
        VStack {
            Image(systemName: "star.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            Text("Latihan Selesai!")
                .font(.title)
        }
    }
    
    private var instructionText: some View {
        Text(instructionForCurrentState)
            .font(.system(size: 18, weight: .medium))
            .background(Color.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 50)
            .padding(.horizontal, 48)
    }
    
    private var instructionForCurrentState: String {
        switch trainingState {
        case .positioning: return "Sesuaikan Posisi Anda di dalam Kotak"
        case .ready: return "Posisi sudah optimal! Siap memulai latihan"
        case .training: return "Ikuti gerakan sesuai panduan"
        case .completed: return "Terima kasih sudah berlatih!"
        }
    }
    
    private func startPositioningTimer() {
        positioningTimer = Timer.scheduledTimer(withTimeInterval: positionCheckInterval, repeats: true) { _ in
            if trainingState == .positioning {
                handlePositioning()
            }
        }
    }
}
