//
//  TrainingSessionProtocol.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import Vision

/// Protocol defining training session management capabilities
protocol TrainingSessionProtocol {
    /// The current pose being practiced
    var currentPose: PoseData? { get }
    
    /// The current session scores for each attempted pose
    var sessionScores: [String: [Double]] { get }
    
    /// Start a new training session
    /// - Parameter poses: Array of poses to practice in this session
    func startSession(with poses: [PoseData])
    
    /// End the current training session and calculate results
    /// - Returns: Dictionary with session statistics
    func endSession() -> [String: Any]
    
    /// Advance to the next pose in the sequence
    /// - Returns: The next pose, or nil if complete
    func nextPose() -> PoseData?
    
    /// Evaluate the current detected pose against the reference
    /// - Parameter detectedPose: Dictionary of detected joint positions
    /// - Returns: Evaluation result with score and feedback
    func evaluatePose(detectedPose: [HumanBodyPoseObservation.JointName: CGPoint]) -> (score: Double, feedback: String)
    
    /// Record a pose attempt with its score
    /// - Parameters:
    ///   - poseId: The ID of the attempted pose
    ///   - score: The similarity score (0.0-1.0)
    func recordAttempt(poseId: String, score: Double)
} 