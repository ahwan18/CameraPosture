//
//  LatihanViewModel.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on [Date]
//

import SwiftUI
import Vision
import Foundation

@MainActor
class LatihanViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let poseMatchingManager: PoseMatchingManager
    private let voiceInstructionManager: VoiceInstructionManager
    private let timerManager: TimerManager
    let poseProgressManager: PoseProgressManager
    
    // MARK: - Camera & Pose Detection
    @Published var cameraVM = CameraViewModel()
    @Published var poseViewModel = PoseEstimationViewModel()
    
    // MARK: - UI State
    @Published var showTutorial = false
    @Published private(set) var isAtOptimalDistance: Bool = true
    @Published private(set) var isPoseMatched: Bool = false
    @Published private(set) var holdProgress: Double = 0.0
    @Published private(set) var countdownValue: Int = 8
    @Published private(set) var currentPoseIndex: Int = 0
    @Published private(set) var showPoseTransition: Bool = false
    @Published private(set) var showCompletionMessage: Bool = false
    
    // MARK: - Internal State
    private var wasAtOptimalDistance: Bool = true
    
    // MARK: - Computed Properties
    var currentTargetPose: PoseData? {
        return poseProgressManager.currentTargetPose
    }
    
    var currentPoseDisplayText: String {
        return poseProgressManager.currentPoseDisplayText
    }
    
    var showGuideArrows: Bool {
        return isAtOptimalDistance && !isPoseMatched && !showPoseTransition
    }
    
    // MARK: - Initialization
    init(poseData: [PoseData] = PoseLoader.loadPose()) {
        // Initialize managers
        self.poseMatchingManager = PoseMatchingManager()
        self.voiceInstructionManager = VoiceInstructionManager()
        self.timerManager = TimerManager()
        self.poseProgressManager = PoseProgressManager(poseData: poseData)
        
        // Setup delegates
        setupDelegates()
        
        // Setup pose detection
        setupPoseDetection()
    }
    
    // MARK: - Setup Methods
    private func setupDelegates() {
        poseMatchingManager.delegate = self
        voiceInstructionManager.delegate = self
        timerManager.delegate = self
        poseProgressManager.delegate = self
    }
    
    private func setupPoseDetection() {
        Task {
            await cameraVM.checkPermission()
            cameraVM.delegate = poseViewModel
        }
    }
    
    // MARK: - Public Methods
    
    /// Start the training session
    func startSession() {
        // Enable screen to stay on
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    /// End the training session
    func endSession() {
        // Re-enable screen idle timer
        UIApplication.shared.isIdleTimerDisabled = false
        
        // Clean up all timers
        timerManager.stopHoldTimer()
    }
    
    /// Handle pose detection updates
    func handlePoseDetectionUpdate() {
        guard let targetPose = currentTargetPose else { return }
        
        // Check optimal distance
        let isOptimal = poseMatchingManager.checkOptimalDistance(detectedBodyParts: poseViewModel.detectedBodyParts)
        handleOptimalDistanceChange(isOptimal)
        
        // Only proceed with pose matching if at optimal distance and not in transition
        guard isOptimal && !showPoseTransition else { return }
        
        // Check pose matching
        let poseMatches = poseMatchingManager.checkPoseMatch(
            detectedBodyParts: poseViewModel.detectedBodyParts,
            targetPose: targetPose
        )
        
        handlePoseMatching(poseMatches: poseMatches, targetPose: targetPose)
    }
    
    /// Skip current exercise
    func skipExercise() {
        timerManager.stopHoldTimer()
        poseProgressManager.moveToNextPose()
    }
    
    /// Restart current pose
    func restartCurrentPose() {
        timerManager.stopHoldTimer()
        isPoseMatched = false
    }
}

// MARK: - Private Methods
private extension LatihanViewModel {
    
    /// Handle optimal distance changes
    func handleOptimalDistanceChange(_ isOptimal: Bool) {
        if !isOptimal && wasAtOptimalDistance {
            voiceInstructionManager.announceDistanceAdjustment()
        }
        wasAtOptimalDistance = isOptimal
    }
    
    /// Handle pose matching logic
    func handlePoseMatching(poseMatches: Bool, targetPose: PoseData) {
        // Check if we're in grace period after correction
        let isInGracePeriod = voiceInstructionManager.isInGracePeriod()
        
        if poseMatches && !isInGracePeriod {
            // Pose matches and not in grace period
            if !isPoseMatched {
                // Start holding timer
                isPoseMatched = true
                timerManager.startHoldTimer()
                voiceInstructionManager.announcePoseMatch()
            } else {
                // Continue validating pose during hold
                timerManager.validatePoseForHoldTimer(isPoseValid: true)
            }
        } else {
            // Pose doesn't match or in grace period
            if isPoseMatched {
                // We were holding but pose became incorrect
                timerManager.validatePoseForHoldTimer(isPoseValid: false)
            } else if !isInGracePeriod {
                // Give correction instruction
                providePoseCorrection(targetPose: targetPose)
            }
        }
    }
    
    /// Provide pose correction instruction
    func providePoseCorrection(targetPose: PoseData) {
        let (worstJoint, distance) = poseMatchingManager.findWorstPositionedJoint(
            detectedBodyParts: poseViewModel.detectedBodyParts,
            targetPose: targetPose
        )
        
        guard let joint = worstJoint,
              distance > 0.15,
              let currentPoint = poseViewModel.detectedBodyParts[joint],
              let targetJoint = targetPose.joints[poseMatchingManager.jointNameToKey(joint)] else {
            return
        }
        
        let targetPoint = CGPoint(x: targetJoint.x, y: targetJoint.y)
        voiceInstructionManager.announcePoseCorrection(
            for: joint,
            currentPoint: currentPoint,
            targetPoint: targetPoint
        )
    }
}

// MARK: - PoseMatchingManagerDelegate
extension LatihanViewModel: PoseMatchingManagerDelegate {
    func didUpdateOptimalDistance(_ isOptimal: Bool) {
        isAtOptimalDistance = isOptimal
    }
    
    func didUpdatePoseMatch(_ isMatched: Bool) {
        // This is handled in the main pose matching logic
    }
    
    func didCalculateWorstJoint(_ joint: HumanBodyPoseObservation.JointName?, distance: Double) {
        // This information is used for corrections
    }
}

// MARK: - VoiceInstructionManagerDelegate
extension LatihanViewModel: VoiceInstructionManagerDelegate {
    func didStartVoiceInstruction() {
        // Could be used to show visual feedback
    }
    
    func didFinishVoiceInstruction() {
        // Could be used to hide visual feedback
    }
}

// MARK: - TimerManagerDelegate
extension LatihanViewModel: TimerManagerDelegate {
    func didUpdateHoldProgress(_ progress: Double) {
        holdProgress = progress
    }
    
    func didUpdateCountdown(_ value: Int) {
        countdownValue = value
    }
    
    func didCompleteHoldTimer() {
        isPoseMatched = false
        poseProgressManager.moveToNextPose()
    }
    
    func didFailHoldTimer() {
        isPoseMatched = false
        voiceInstructionManager.announcePoseFailure()
    }
    
    func shouldAnnounceCountdown(_ number: Int) {
        voiceInstructionManager.announceCountdown(number)
    }
}

// MARK: - PoseProgressManagerDelegate
extension LatihanViewModel: PoseProgressManagerDelegate {
    func didUpdateCurrentPose(_ poseIndex: Int) {
        currentPoseIndex = poseIndex
    }
    
    func didStartPoseTransition() {
        showPoseTransition = true
        if poseProgressManager.isLastPose {
            voiceInstructionManager.announcePoseCompletion()
        }
    }
    
    func didFinishPoseTransition() {
        showPoseTransition = false
    }
    
    func didCompleteAllPoses() {
        showCompletionMessage = true
        voiceInstructionManager.announceSessionCompletion()
    }
}

//// MARK: - Helper Extension for PoseMatchingManager
//extension PoseMatchingManager {
//    func jointNameToKey(_ jointName: HumanBodyPoseObservation.JointName) -> String {
//        switch jointName {
//        case .nose: return "nose"
//        case .neck: return "neck"
//        case .leftShoulder: return "leftShoulder"
//        case .rightShoulder: return "rightShoulder"
//        case .leftElbow: return "leftElbow"
//        case .rightElbow: return "rightElbow"
//        case .leftWrist: return "leftWrist"
//        case .rightWrist: return "rightWrist"
//        case .leftHip: return "leftHip"
//        case .rightHip: return "rightHip"
//        case .leftKnee: return "leftKnee"
//        case .rightKnee: return "rightKnee"
//        case .leftAnkle: return "leftAnkle"
//        case .rightAnkle: return "rightAnkle"
//        default: return ""
//        }
//    }
//}
