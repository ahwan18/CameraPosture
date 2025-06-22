import Foundation
import SwiftUI
import Vision

class LatihanViewModel: ObservableObject, PoseTimerManagerDelegate {
    // MARK: - Published Properties (for UI)
    @Published var currentPoseIndex: Int = 0
    @Published var isPoseMatched: Bool = false
    @Published var holdProgress: Double = 0.0
    @Published var countdownValue: Int = 8
    @Published var showCompletionMessage: Bool = false
    @Published var showPoseTransition: Bool = false
    @Published var isAtOptimalDistance: Bool = true
    @Published var poseName: String = "A1"
    
    // MARK: - ViewModels and Managers
    private var poseViewModel: PoseEstimationViewModel
    private var poseMatcher: PoseMatcher
    private var voiceFeedbackManager: VoiceFeedbackManager
    public var poseTimerManager: PoseTimerManager

    // MARK: - Properties
    let poseData: [PoseData]
    private var wasAtOptimalDistance: Bool = true
    private var lastCorrectionTime: Date = .distantPast
    private let correctionGracePeriod: TimeInterval = 2.0
    
    // MARK: - Computed Properties
    var currentTargetPose: PoseData? {
        guard currentPoseIndex < poseData.count else { return nil }
        return poseData[currentPoseIndex]
    }

    var nextTargetPose: PoseData? {
        let nextIndex = currentPoseIndex + 1
        guard nextIndex < poseData.count else { return nil }
        return poseData[nextIndex]
    }

    // MARK: - Initialization
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
    }
    
    // MARK: - Main Logic
    func updatePose() {
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

    // MARK: - PoseTimerManagerDelegate
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
    
    // MARK: - Private Helpers
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
