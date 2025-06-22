//
//  PoseServiceProtocol.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import Vision

/// Protocol defining pose detection and loading operations
protocol PoseServiceProtocol {
    /// Load pose data from storage
    /// - Returns: Array of pose data
    func loadPoses() -> [PoseData]
    
    /// Analyze a pose against reference poses
    /// - Parameters:
    ///   - detectedPose: The detected pose points
    ///   - referencePose: The reference pose to match against
    /// - Returns: Similarity score between 0.0 and 1.0
    func analyzePoseSimilarity(detectedPose: [HumanBodyPoseObservation.JointName: CGPoint], against referencePose: PoseData) -> Double
    
    /// Get the joints that need improvement in the current pose
    /// - Parameters:
    ///   - detectedPose: The detected pose points
    ///   - referencePose: The reference pose to match against
    /// - Returns: Array of joint names that need improvement
    func getImproveableJoints(detectedPose: [HumanBodyPoseObservation.JointName: CGPoint], against referencePose: PoseData) -> [HumanBodyPoseObservation.JointName]
} 