import Foundation
import Vision
import CoreGraphics

/// Protocol defining pose matching capabilities
protocol PoseMatcherProtocol {
    /// Checks if the current pose matches the target pose at the specified index
    /// - Parameter currentPoseIndex: The index of the target pose to match against
    /// - Returns: Boolean indicating whether the poses match
    func checkPoseMatch(currentPoseIndex: Int) -> Bool
    
    /// Converts a Vision joint name to a string key format
    /// - Parameter jointName: The Vision joint name to convert
    /// - Returns: String key representation of the joint
    static func jointNameToKey(_ jointName: HumanBodyPoseObservation.JointName) -> String
} 