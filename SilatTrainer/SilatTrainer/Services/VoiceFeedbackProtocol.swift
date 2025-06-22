//
//  VoiceFeedbackProtocol.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import AVFoundation
import Vision
import CoreGraphics

/// Protocol defining voice feedback and spoken instruction capabilities for pose training
protocol VoiceFeedbackProtocol {
    /// Speak a text message with optional interruption control and completion handler
    /// - Parameters:
    ///   - text: The message to speak
    ///   - interrupt: Whether to interrupt current speech
    ///   - completion: Optional completion handler
    func speak(_ text: String, interrupt: Bool, completion: (() -> Void)?)
    
    /// Announce whether the user's distance from the camera is optimal
    /// - Parameters:
    ///   - isOptimal: Whether the current distance is optimal
    ///   - wasOptimal: Whether the previous distance was optimal
    func announceDistance(isOptimal: Bool, wasOptimal: Bool)
    
    /// Announce when a pose is correctly matched
    func announcePoseMatch()
    
    /// Announce the countdown for holding a pose
    /// - Parameter second: The current countdown second
    func announceHoldCountdown(second: Int)
    
    /// Announce when a pose attempt fails
    func announcePoseFailure()
    
    /// Announce completion of a pose
    /// - Parameter isLastPose: Whether this is the last pose in the sequence
    func announcePoseCompletion(isLastPose: Bool)
    
    /// Provide correction guidance for joints that need adjustment
    /// - Parameters:
    ///   - isPoseMatched: Whether the current pose is matched
    ///   - currentTargetPose: The target pose data being attempted
    func giveJointCorrection(isPoseMatched: Bool, currentTargetPose: PoseData)
    
    /// Announce a training event
    /// - Parameter event: The event type (start, complete, rest, etc.)
    func announceTrainingEvent(_ event: String)
    
    /// Provide voice feedback based on pose similarity
    /// - Parameters:
    ///   - similarity: The similarity score
    ///   - poseName: The name of the pose being attempted
    func provideFeedback(similarity: Double, for poseName: String)
    
    /// Provide corrective guidance for specific joints
    /// - Parameters:
    ///   - joints: Array of joint names that need improvement
    ///   - poseName: The name of the pose being attempted
    func provideJointCorrection(for joints: [String], in poseName: String)
} 