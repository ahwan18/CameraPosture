import Foundation
import Combine
import SwiftUI

class TrainingViewModel: ObservableObject {
    @Published var currentPoseIndex: Int = 0
    @Published var trainingProgress = TrainingProgress()
    @Published var isTraining = false
    @Published var showCompletionView = false
    @Published var currentComparisonResult: PoseComparisonResult?
    @Published var warningMessage: String?
    
    let cameraService = CameraService()
    private let audioService = AudioFeedbackService.shared
    private let poseDataService = PoseDataService.shared
    private let comparisonService = PoseComparisonService.shared
    
    private var poses: [JurusPose] = []
    private var cancellables = Set<AnyCancellable>()
    private var poseHoldTimer: Timer?
    private var lastAudioFeedbackTime: Date?
    
    var currentPose: JurusPose? {
        guard currentPoseIndex < poses.count else { return nil }
        return poses[currentPoseIndex]
    }
    
    var progressText: String {
        "Pose \(currentPoseIndex + 1) dari \(poses.count)"
    }
    
    var holdTimeRemaining: Int {
        let holdDuration = trainingProgress.holdDuration
        let remaining = max(0, Int(TrainingConfig.requiredHoldDuration - holdDuration))
        return remaining
    }
    
    init() {
        setupPoseData()
        setupCameraObservers()
    }
    
    private func setupPoseData() {
        poses = poseDataService.loadAllPosesForJurus()
    }
    
    private func setupCameraObservers() {
        // Observe detected poses
        cameraService.$detectedPose
            .compactMap { $0 }
            .sink { [weak self] detectedPose in
                self?.processPoseDetection(detectedPose)
            }
            .store(in: &cancellables)
        
        // Observe camera permission
        cameraService.$cameraPermissionStatus
            .sink { [weak self] status in
                if status == .denied {
                    self?.warningMessage = "Akses kamera diperlukan untuk latihan"
                }
            }
            .store(in: &cancellables)
    }
    
    func startTraining(from poseIndex: Int = 0) {
        currentPoseIndex = poseIndex
        trainingProgress = TrainingProgress()
        trainingProgress.currentPoseIndex = poseIndex
        isTraining = true
        showCompletionView = false
        
        cameraService.startSession()
        
        // Announce first pose
        if let pose = currentPose {
            audioService.speakPoseInstruction(pose.name)
        }
    }
    
    func stopTraining() {
        isTraining = false
        cameraService.stopSession()
        audioService.stopSpeaking()
        poseHoldTimer?.invalidate()
        poseHoldTimer = nil
    }
    
    private func processPoseDetection(_ detectedPose: DetectedPose) {
        guard isTraining,
              let currentPose = currentPose,
              let poseReference = currentPose.poseReference else { return }
        
        // Compare poses
        let comparisonResult = comparisonService.comparePoses(
            detected: detectedPose,
            reference: poseReference
        )
        
        DispatchQueue.main.async {
            self.currentComparisonResult = comparisonResult
        }
        
        // Handle pose correctness
        if comparisonResult.isCorrect {
            if !trainingProgress.isHoldingCorrectPose {
                // Just started holding correct pose
                trainingProgress.startHoldingPose()
                audioService.speakEncouragement()
                startPoseHoldTimer()
            }
        } else {
            if trainingProgress.isHoldingCorrectPose {
                // Lost correct pose
                trainingProgress.stopHoldingPose()
                poseHoldTimer?.invalidate()
                poseHoldTimer = nil
            }
            
            // Provide audio feedback for corrections
            provideCorrectionFeedback(comparisonResult.feedbackMessages)
        }
    }
    
    private func startPoseHoldTimer() {
        poseHoldTimer?.invalidate()
        
        poseHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.trainingProgress.holdDuration >= TrainingConfig.requiredHoldDuration {
                self.completePose()
            }
        }
    }
    
    private func completePose() {
        poseHoldTimer?.invalidate()
        poseHoldTimer = nil
        
        trainingProgress.completedPoses.insert(currentPoseIndex)
        audioService.speakPoseCompleted()
        
        // Move to next pose after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.moveToNextPose()
        }
    }
    
    private func moveToNextPose() {
        currentPoseIndex += 1
        
        if currentPoseIndex >= poses.count {
            // Training completed
            completeTraining()
        } else {
            // Continue to next pose
            trainingProgress.currentPoseIndex = currentPoseIndex
            trainingProgress.stopHoldingPose()
            
            if let pose = currentPose {
                audioService.speakPoseInstruction(pose.name)
            }
        }
    }
    
    private func completeTraining() {
        stopTraining()
        showCompletionView = true
        audioService.speakTrainingCompleted()
    }
    
    private func provideCorrectionFeedback(_ messages: [String]) {
        guard !messages.isEmpty else { return }
        
        // Check if enough time has passed since last feedback
        if let lastTime = lastAudioFeedbackTime {
            let timeSinceLastFeedback = Date().timeIntervalSince(lastTime)
            if timeSinceLastFeedback < TrainingConfig.audioFeedbackDelay {
                return
            }
        }
        
        // Speak the first correction message
        if let firstMessage = messages.first {
            audioService.speakCorrection(firstMessage)
            lastAudioFeedbackTime = Date()
        }
    }
    
    func checkPersonSize(joints: [JointName: CGPoint]) -> Bool {
        // Check if person is properly visible in frame
        guard let leftAnkle = joints[.leftAnkle],
              let rightAnkle = joints[.rightAnkle],
              let nose = joints[.nose] else {
            warningMessage = "Pastikan seluruh tubuh terlihat di kamera"
            return false
        }
        
        let personHeight = abs(nose.y - max(leftAnkle.y, rightAnkle.y))
        
        if personHeight < TrainingConfig.minimumPersonSizeThreshold {
            warningMessage = "Mundur dari kamera agar seluruh tubuh terlihat"
            return false
        }
        
        warningMessage = nil
        return true
    }
} 