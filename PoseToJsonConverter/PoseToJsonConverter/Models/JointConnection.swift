import Foundation

struct JointConnection: Identifiable {
    let id = UUID()
    let from: JointName
    let to: JointName
    
    static let defaultConnections: [JointConnection] = [
        // Torso connections
        JointConnection(from: .neck, to: .rightShoulder),
        JointConnection(from: .neck, to: .leftShoulder),
        JointConnection(from: .rightShoulder, to: .rightElbow),
        JointConnection(from: .leftShoulder, to: .leftElbow),
        JointConnection(from: .rightElbow, to: .rightWrist),
        JointConnection(from: .leftElbow, to: .leftWrist),
        
        // Leg connections
        JointConnection(from: .rightHip, to: .rightKnee),
        JointConnection(from: .leftHip, to: .leftKnee),
        JointConnection(from: .rightKnee, to: .rightAnkle),
        JointConnection(from: .leftKnee, to: .leftAnkle),
        
        // Hip connections
        JointConnection(from: .leftHip, to: .rightHip),
        
        // Hip to Torso
        JointConnection(from: .leftHip, to: .rightShoulder),
        JointConnection(from: .rightHip, to: .leftShoulder),
        
        // Head connection
        JointConnection(from: .neck, to: .nose)
    ]
    
    // Helper untuk mengecek apakah joint harus diabaikan
    static func shouldIgnoreJoint(_ joint: JointName) -> Bool {
        switch joint {
        case .leftEye, .rightEye, .leftEar, .rightEar, .root:
            return true
        default:
            return false
        }
    }
} 
