import Foundation
import SwiftUI
import Vision

enum LatihanPhase {
    case positioning
    case countdown
    case evaluating
}

class LatihanViewModel: ObservableObject, PoseTimerManagerDelegate {
    // - Published Properties (for UI)
    @Published var currentPoseIndex: Int = 0
    @Published var isPoseMatched: Bool = false
    @Published var holdProgress: Double = 0.0
    @Published var countdownValue: Int = 8
    @Published var showCompletionMessage: Bool = false
    @Published var showPoseTransition: Bool = false
    @Published var isAtOptimalDistance: Bool = true
    @Published var poseName: String = "A1"
    
    // Positioning and countdown properties
    @Published var phase: LatihanPhase = .positioning
    @Published var positioningCountdownValue: Int = 3
    @Published var isUserPositioned: Bool = false
    
    //- ViewModels and Managers
    private var poseViewModel: PoseEstimationViewModel
    private var poseMatcher: PoseMatcher
    private var voiceFeedbackManager: VoiceFeedbackManager
    public var poseTimerManager: PoseTimerManager

    // - Properties
    let poseData: [PoseData]
    private var wasAtOptimalDistance: Bool = true
    private var lastCorrectionTime: Date = .distantPast
    private let correctionGracePeriod: TimeInterval = 2.0
    private var countdownTimer: Timer?
    private let fittingBox = CGRect(x: 0.15, y: 0.1, width: 0.7, height: 0.8)
    
    // - Computed Properties
    var currentTargetPose: PoseData? {
        guard currentPoseIndex < poseData.count else { return nil }
        return poseData[currentPoseIndex]
    }

    var nextTargetPose: PoseData? {
        let nextIndex = currentPoseIndex + 1
        guard nextIndex < poseData.count else { return nil }
        return poseData[nextIndex]
    }

    // - Initialization
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
    
    func cleanup() {
        poseTimerManager.stopTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    // - Main Logic
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

    private func evaluatePose() {
        self.isAtOptimalDistance = checkOptimalDistance()
        
        if isAtOptimalDistance != wasAtOptimalDistance {
            voiceFeedbackManager.announceDistance(isOptimal: isAtOptimalDistance, wasOptimal: wasAtOptimalDistance)
            wasAtOptimalDistance = isAtOptimalDistance
        }
        
        guard !showPoseTransition else { return }
        
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        let isInGracePeriod = timeSinceCorrection < correctionGracePeriod
        
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

    // - PoseTimerManagerDelegate
    func poseTimerDidComplete() {
        isPoseMatched = false
        
        if currentPoseIndex < poseData.count - 1 {
            showPoseTransition = true
            
            let completionText = "Bagus! Lanjut ke gerakan berikutnya"
            voiceFeedbackManager.speak(completionText, interrupt: true) {
                // Ini adalah trailing closure yang benar
                // Blok ini akan dijalankan HANYA SETELAH suara "Bagus!..." selesai.
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
    
    func poseTimerDidFail() {
        voiceFeedbackManager.announcePoseFailure()
        lastCorrectionTime = Date()
        isPoseMatched = false
        holdProgress = 0.0
        countdownValue = 8
    }
    
    func poseTimerDidUpdate(countdown: Int, progress: Double) {
        if self.countdownValue != countdown && countdown > 0 {
             voiceFeedbackManager.announceHoldCountdown(second: countdown)
        }
        self.countdownValue = countdown
        self.holdProgress = progress
    }
    
    func isPoseStillValid() -> Bool {
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        let isInGracePeriod = timeSinceCorrection < correctionGracePeriod
        
        return isAtOptimalDistance && poseMatcher.checkPoseMatch(currentPoseIndex: currentPoseIndex) && !isInGracePeriod
    }
    
    // - Private Helpers
    
    private func checkUserPosition() -> Bool {
        let allJointsVisible = checkOptimalDistance()
        
        if poseViewModel.detectedBodyParts.isEmpty {
            return false
        }
        
        for point in poseViewModel.detectedBodyParts.values {
            if !fittingBox.contains(point) {
                return false
            }
        }
        
        return allJointsVisible
    }
    
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
    
    private func resetToPositioningPhase() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        phase = .positioning
        positioningCountdownValue = 3
        voiceFeedbackManager.speak("Posisi salah, kembali ke dalam kotak", interrupt: true)
    }
    
    private func checkOptimalDistance() -> Bool {
        let requiredJoints: [HumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        return requiredJoints.allSatisfy { poseViewModel.detectedBodyParts[$0] != nil }
    }
    
    private func resetForNextPose() {
        isPoseMatched = false
        holdProgress = 0.0
        countdownValue = 8
        lastCorrectionTime = .distantPast
    }
    
    private func updatePoseName() {
        if currentPoseIndex < poseData.count {
            poseName = "A\(currentPoseIndex + 1)"
        }
    }
} 
