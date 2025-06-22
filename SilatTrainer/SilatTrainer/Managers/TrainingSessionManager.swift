//
//  TrainingSessionManager.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import Vision

class TrainingSessionManager: TrainingSessionProtocol {
    static let shared = TrainingSessionManager()
    
    private(set) var currentPose: PoseData?
    private(set) var sessionScores: [String: [Double]] = [:]
    private var poseQueue: [PoseData] = []
    private var poseIndex = 0
    private let poseService: PoseServiceProtocol
    private let voiceService: VoiceFeedbackProtocol
    
    init(poseService: PoseServiceProtocol = PoseLoader.shared, 
         voiceService: VoiceFeedbackProtocol = VoiceHelper.shared as! VoiceFeedbackProtocol) {
        self.poseService = poseService
        self.voiceService = voiceService
    }
    
    func startSession(with poses: [PoseData]) {
        sessionScores = [:]
        poseQueue = poses
        poseIndex = 0
        
        if !poses.isEmpty {
            currentPose = poses[0]
            voiceService.announceTrainingEvent("start")
        }
    }
    
    func endSession() -> [String: Any] {
        let results: [String: Any] = [
            "scores": sessionScores,
            "completedPoses": poseIndex,
            "totalPoses": poseQueue.count,
            "averageScore": calculateAverageScore(),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        voiceService.announceTrainingEvent("end")
        
        // Reset session
        currentPose = nil
        poseQueue = []
        
        return results
    }
    
    func nextPose() -> PoseData? {
        guard !poseQueue.isEmpty else { return nil }
        
        poseIndex += 1
        if poseIndex < poseQueue.count {
            currentPose = poseQueue[poseIndex]
            voiceService.announceTrainingEvent("rest")
            return currentPose
        } else {
            currentPose = nil
            return nil
        }
    }
    
    func evaluatePose(detectedPose: [HumanBodyPoseObservation.JointName: CGPoint]) -> (score: Double, feedback: String) {
        guard let pose = currentPose else {
            return (0.0, "No active pose to evaluate")
        }
        
        // Calculate similarity
        let score = poseService.analyzePoseSimilarity(detectedPose: detectedPose, against: pose)
        
        // Get joints that need improvement
        let improvableJoints = poseService.getImproveableJoints(detectedPose: detectedPose, against: pose)
        
        // Convert joint names to strings for feedback
        let jointNames = improvableJoints.map { String(describing: $0) }
        
        // Determine feedback
        var feedbackMessage = ""
        if score > 0.85 {
            feedbackMessage = "Excellent form!"
            voiceService.provideFeedback(similarity: score, for: pose.poseId)
        } else {
            voiceService.provideJointCorrection(for: jointNames, in: pose.poseId)
        }
        
        // Record this attempt
        recordAttempt(poseId: pose.poseId, score: score)
        
        return (score, feedbackMessage)
    }
    
    func recordAttempt(poseId: String, score: Double) {
        if sessionScores[poseId] == nil {
            sessionScores[poseId] = []
        }
        sessionScores[poseId]?.append(score)
    }
    
    private func calculateAverageScore() -> Double {
        var totalScore = 0.0
        var count = 0
        
        for scores in sessionScores.values {
            totalScore += scores.reduce(0.0, +)
            count += scores.count
        }
        
        return count > 0 ? totalScore / Double(count) : 0.0
    }
} 
