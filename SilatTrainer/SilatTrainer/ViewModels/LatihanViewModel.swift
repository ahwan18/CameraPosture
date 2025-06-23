import Foundation
import SwiftUI
import Vision

/// Represents the different phases of training exercises
enum LatihanPhase {
    case positioning  // User is getting into position
    case countdown    // Countdown before starting the exercise
    case evaluating   // Evaluating the user's pose against the target pose
}

/// ViewModel that manages the training exercise flow, pose matching, timers, and feedback.
/// Handles user positioning, pose evaluation, and progression through multiple poses.
class LatihanViewModel: ObservableObject, PoseTimerManagerDelegate {
    // - Published Properties (for UI)
    @Published var currentPoseIndex: Int = 0
    @Published var isPoseMatched: Bool = false      // Whether the current pose is matched
    @Published var holdProgress: Double = 0.0       // Progress of holding the current pose (0.0 to 1.0)
    @Published var countdownValue: Int = 8          // Countdown seconds for holding a pose
    @Published var showCompletionMessage: Bool = false  // Whether to show completion message
    @Published var showPoseTransition: Bool = false     // Whether transitioning between poses
    @Published var isAtOptimalDistance: Bool = true     // Whether user is at optimal distance for detection
    @Published var poseName: String = "A1"              // Current pose name for display
    
    // - Positioning and countdown properties
    @Published var phase: LatihanPhase = .positioning   // Current phase of exercise
    @Published var positioningCountdownValue: Int = 3   // Countdown before starting pose evaluation
    @Published var isUserPositioned: Bool = false       // Whether user is properly positioned
    
    //  - ViewModels and Managers
    private var poseViewModel: PoseEstimationViewModel  // Handles pose detection
    private var poseMatcher: PoseMatcher                // Matches detected pose with target pose
    private var voiceFeedbackManager: VoiceFeedbackManager  // Provides voice guidance
    public var poseTimerManager: PoseTimerManager       // Manages pose holding time

    //   - Properties
    let poseData: [PoseData]                           // Collection of target poses
    private var wasAtOptimalDistance: Bool = true      // Previous optimal distance state
    private var lastCorrectionTime: Date = .distantPast  // Last time correction was given
    private let correctionGracePeriod: TimeInterval = 2.0  // Seconds to wait before giving another correction
    private var countdownTimer: Timer?                  // Timer for positioning countdown
    private let fittingBox = CGRect(x: 0.15, y: 0.1, width: 0.7, height: 0.8)  // Area where user should position
    
    //   - Computed Properties
    
    /// The current target pose that the user should match
    var currentTargetPose: PoseData? {
        guard currentPoseIndex < poseData.count else { return nil }
        return poseData[currentPoseIndex]
    }

    /// The next target pose in the sequence
    var nextTargetPose: PoseData? {
        let nextIndex = currentPoseIndex + 1
        guard nextIndex < poseData.count else { return nil }
        return poseData[nextIndex]
    }

    //   - Initialization
    
    /// Initializes the view model with a pose detection view model
    /// - Parameter poseViewModel: The view model responsible for pose detection
    init(poseViewModel: PoseEstimationViewModel) {
        self.poseViewModel = poseViewModel
        self.poseData = PoseLoader.loadPose()
        
        self.poseMatcher = PoseMatcher(poseData: poseData, poseViewModel: poseViewModel)
        self.poseTimerManager = PoseTimerManager()
        // Must be initialized after self is available
        self.voiceFeedbackManager = VoiceFeedbackManager(poseViewModel: poseViewModel, poseData: poseData)
        
        self.poseTimerManager.delegate = self
        
        updatePoseName()
    }
    
    /// Cleans up timers and resources
    func cleanup() {
        poseTimerManager.stopTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    //   - Main Logic
    
    /// Updates the training state based on user position and current phase
    /// Called regularly to process new pose detection data
    func update() {
        self.isUserPositioned = checkUserPosition()

        switch phase {
        case .positioning:
            if isUserPositioned {
                startPositioningCountdown()
            }
        case .countdown:
            if !isUserPositioned {
                resetToPositioningPhase()
            }
        case .evaluating:
            evaluatePose()
        }
    }

    /// Evaluates the detected pose against the target pose and provides feedback
    private func evaluatePose() {
        self.isAtOptimalDistance = checkOptimalDistance()
        
        // Announce change in distance status
        if isAtOptimalDistance != wasAtOptimalDistance {
            voiceFeedbackManager.announceDistance(isOptimal: isAtOptimalDistance, wasOptimal: wasAtOptimalDistance)
            wasAtOptimalDistance = isAtOptimalDistance
        }
        
        // Skip evaluation during pose transitions
        guard !showPoseTransition else { return }
        
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        let isInGracePeriod = timeSinceCorrection < correctionGracePeriod
        
        // Check if the detected pose matches the target pose
        let poseMatches = isAtOptimalDistance && poseMatcher.checkPoseMatch(currentPoseIndex: currentPoseIndex)
        
        if poseMatches && !isInGracePeriod {
            if !isPoseMatched {
                isPoseMatched = true
                voiceFeedbackManager.announcePoseMatch()
                poseTimerManager.startTimer()
            }
        } else {
            if isPoseMatched {
                // This state is handled by the timer manager's delegate callbacks
            } else if isAtOptimalDistance && !isInGracePeriod {
                if let targetPose = currentTargetPose {
                    voiceFeedbackManager.giveJointCorrection(isPoseMatched: isPoseMatched, currentTargetPose: targetPose)
                }
            }
        }
    }

    //   - PoseTimerManagerDelegate
    
    /// Called when the pose has been held for the required duration
    func poseTimerDidComplete() {
        isPoseMatched = false
        
        if currentPoseIndex < poseData.count - 1 {
            showPoseTransition = true
            
            let completionText = "Bagus! Lanjut ke gerakan berikutnya"
            voiceFeedbackManager.speak(completionText, interrupt: true) {
                // This closure will execute ONLY AFTER the "Bagus!..." voice has finished
                self.currentPoseIndex += 1
                self.updatePoseName()
                self.showPoseTransition = false
                self.resetForNextPose()
            }
        } else {
            showCompletionMessage = true
            voiceFeedbackManager.speak("Selamat! Semua gerakan telah diselesaikan.", interrupt: true)
        }
    }
    
    /// Called when the pose is no longer held correctly during the timer
    func poseTimerDidFail() {
        voiceFeedbackManager.announcePoseFailure()
        lastCorrectionTime = Date()
        isPoseMatched = false
        holdProgress = 0.0
        countdownValue = 8
    }
    
    /// Called when the timer updates with new countdown value and progress
    func poseTimerDidUpdate(countdown: Int, progress: Double) {
        if self.countdownValue != countdown && countdown > 0 {
             voiceFeedbackManager.announceHoldCountdown(second: countdown)
        }
        self.countdownValue = countdown
        self.holdProgress = progress
    }
    
    /// Checks if the current pose is still valid for timing
    /// - Returns: Boolean indicating if the pose is still valid
    func isPoseStillValid() -> Bool {
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        let isInGracePeriod = timeSinceCorrection < correctionGracePeriod
        
        return isAtOptimalDistance && poseMatcher.checkPoseMatch(currentPoseIndex: currentPoseIndex) && !isInGracePeriod
    }
    
    //   - Private Helpers
    
    /// Checks if the user is properly positioned within the fitting box
    /// - Returns: Boolean indicating if user is properly positioned
    private func checkUserPosition() -> Bool {
        let allJointsVisible = checkOptimalDistance()
        
        if poseViewModel.detectedBodyParts.isEmpty {
            return false
        }
        
        // Check if all detected body parts are within the fitting box
        for point in poseViewModel.detectedBodyParts.values {
            if !fittingBox.contains(point) {
                return false
            }
        }
        
        return allJointsVisible
    }
    
    /// Starts the countdown before beginning pose evaluation
    private func startPositioningCountdown() {
        phase = .countdown
        positioningCountdownValue = 3
        
        countdownTimer?.invalidate()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.positioningCountdownValue -= 1
            
            if self.positioningCountdownValue > 0 {
                self.voiceFeedbackManager.speak("\(self.positioningCountdownValue)", interrupt: true)
            }
            
            if self.positioningCountdownValue <= 0 {
                self.countdownTimer?.invalidate()
                self.phase = .evaluating
                self.voiceFeedbackManager.speak("Mulai!", interrupt: true)
            }
        }
    }
    
    /// Resets back to positioning phase when user moves out of position
    private func resetToPositioningPhase() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        phase = .positioning
        positioningCountdownValue = 3
        voiceFeedbackManager.speak("Posisi salah, kembali ke dalam kotak", interrupt: true)
    }
    
    /// Checks if all required joints are visible for optimal pose detection
    /// - Returns: Boolean indicating if all required joints are detected
    private func checkOptimalDistance() -> Bool {
        let requiredJoints: [HumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        return requiredJoints.allSatisfy { poseViewModel.detectedBodyParts[$0] != nil }
    }
    
    /// Resets all state variables for the next pose
    private func resetForNextPose() {
        isPoseMatched = false
        holdProgress = 0.0
        countdownValue = 8
        lastCorrectionTime = .distantPast
    }
    
    /// Updates the display name of the current pose
    private func updatePoseName() {
        if currentPoseIndex < poseData.count {
            poseName = "A\(currentPoseIndex + 1)"
        }
    }
} 
