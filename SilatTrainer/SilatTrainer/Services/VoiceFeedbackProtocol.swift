//
//  VoiceFeedbackProtocol.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation

/// Protocol defining voice feedback and spoken instruction capabilities
protocol VoiceFeedbackProtocol {
    /// Speak a message using text-to-speech
    /// - Parameter message: The message to speak
    func speak(_ message: String)
    
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
    
    /// Announce a training event
    /// - Parameter event: The event type (start, complete, rest, etc.)
    func announceTrainingEvent(_ event: String)
} 