import Foundation
import UIKit
import AVFoundation

// MARK: - Core Data Models

/// Represents a single posture/pose that users can practice
struct Posture: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let imageName: String
    var image: UIImage?
    
    init(name: String, imageName: String, image: UIImage? = nil) {
        self.name = name
        self.imageName = imageName
        self.image = image
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Posture, rhs: Posture) -> Bool {
        lhs.id == rhs.id
    }
}

/// Basic pose information without heavy UIImage data
struct PoseInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let filename: String
    
    init(name: String, filename: String) {
        self.name = name
        self.filename = filename
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PoseInfo, rhs: PoseInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Training session state for sequential pose training
struct TrainingSession {
    let id = UUID()
    let poses: [Posture]
    var currentPoseIndex: Int
    var isCompleted: Bool
    var startTime: Date
    var completedPoses: [UUID]
    
    init(poses: [Posture]) {
        self.poses = poses
        self.currentPoseIndex = 0
        self.isCompleted = false
        self.startTime = Date()
        self.completedPoses = []
    }
    
    var currentPose: Posture? {
        guard currentPoseIndex < poses.count else { return nil }
        return poses[currentPoseIndex]
    }
    
    var totalPoses: Int {
        poses.count
    }
    
    var progress: Double {
        guard totalPoses > 0 else { return 0 }
        return Double(currentPoseIndex) / Double(totalPoses)
    }
    
    mutating func moveToNextPose() {
        if let currentPose = currentPose {
            completedPoses.append(currentPose.id)
        }
        currentPoseIndex += 1
        if currentPoseIndex >= poses.count {
            isCompleted = true
        }
    }
    
    mutating func reset() {
        currentPoseIndex = 0
        isCompleted = false
        startTime = Date()
        completedPoses.removeAll()
    }
    
    mutating func resetToFirstPose() {
        currentPoseIndex = 0
        isCompleted = false
        // Keep startTime and completedPoses as they were
    }
}

/// Hold timer state for pose validation
struct HoldTimer {
    let requiredDuration: TimeInterval
    var remainingTime: TimeInterval
    var isActive: Bool
    var progress: Double {
        1.0 - (remainingTime / requiredDuration)
    }
    
    init(requiredDuration: TimeInterval = 3.0) {
        self.requiredDuration = requiredDuration
        self.remainingTime = requiredDuration
        self.isActive = false
    }
    
    mutating func start() {
        isActive = true
        remainingTime = requiredDuration
    }
    
    mutating func stop() {
        isActive = false
        remainingTime = requiredDuration
    }
    
    mutating func tick(by interval: TimeInterval) -> Bool {
        guard isActive else { return false }
        remainingTime -= interval
        if remainingTime <= 0 {
            isActive = false
            return true // Timer completed
        }
        return false
    }
}

/// Camera configuration and state
struct CameraConfiguration {
    var position: AVCaptureDevice.Position
    var isSessionRunning: Bool
    var hasPermission: Bool
    
    init() {
        self.position = .front
        self.isSessionRunning = false
        self.hasPermission = false
    }
}

/// Pose matching result
struct PoseMatchResult {
    let isMatched: Bool
    let confidence: Double
    let timestamp: Date
    
    init(isMatched: Bool, confidence: Double) {
        self.isMatched = isMatched
        self.confidence = confidence
        self.timestamp = Date()
    }
} 