import Foundation

struct TrainingConfig {
    // Threshold untuk menentukan pose benar (85% default, bisa diubah)
    static var similarityThreshold: Double = 0.85
    
    // Durasi minimal untuk menahan pose (3 detik)
    static let requiredHoldDuration: TimeInterval = 3.0
    
    // Delay minimal antar audio feedback (3 detik)
    static let audioFeedbackDelay: TimeInterval = 3.0
    
    // Threshold untuk joint yang dianggap "dekat" dengan target
    static let jointDistanceThreshold: Double = 0.1 // 10% dari normalized space
    
    // Confidence minimal untuk joint detection
    static let minimumJointConfidence: Float = 0.1
    
    // Frame rate untuk pose detection (fps)
    static let poseDetectionFrameRate: Double = 15.0
    
    // Ukuran minimum person dalam frame (percentage)
    static let minimumPersonSizeThreshold: Double = 0.3
} 