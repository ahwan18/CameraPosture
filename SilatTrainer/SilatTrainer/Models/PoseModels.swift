import Foundation
import Vision
import CoreGraphics

// Model untuk menyimpan data pose reference dari JSON
struct PoseReference: Codable {
    let poseId: String
    let joints: [String: Joint]
    let ignoredJoints: [String]
    let importantJoints: [String]
}

// Model untuk joint individual
struct Joint: Codable {
    let x: CGFloat
    let y: CGFloat
    let confidence: CGFloat
}

// Model untuk pose yang terdeteksi dari user
struct DetectedPose {
    let joints: [JointName: CGPoint]
    let timestamp: Date
}

// Model untuk hasil perbandingan pose
struct PoseComparisonResult {
    let overallSimilarity: Double
    let jointErrors: [JointName: JointError]
    let isCorrect: Bool
    let feedbackMessages: [String]
}

// Model untuk error pada joint
struct JointError {
    let jointName: JointName
    let currentPosition: CGPoint
    let targetPosition: CGPoint
    let distance: Double
    let direction: CGVector // Arah koreksi
    
    var correctionMessage: String {
        let threshold: Double = 0.1 // 10% dari normalized space
        
        if distance < threshold {
            return ""
        }
        
        let jointDisplayName = jointName.displayName
        
        // Tentukan arah gerakan berdasarkan vektor
        if abs(direction.dx) > abs(direction.dy) {
            // Gerakan horizontal lebih dominan
            if direction.dx > 0 {
                return "\(jointDisplayName) kurang ke kanan"
            } else {
                return "\(jointDisplayName) kurang ke kiri"
            }
        } else {
            // Gerakan vertikal lebih dominan
            if direction.dy > 0 {
                return "\(jointDisplayName) kurang naik"
            } else {
                return "\(jointDisplayName) kurang turun"
            }
        }
    }
}

// Enum untuk nama-nama joint
enum JointName: String, CaseIterable, Codable {
    // Head
    case nose = "nose"
    case leftEye = "leftEye"
    case rightEye = "rightEye"
    case leftEar = "leftEar"
    case rightEar = "rightEar"
    case neck = "neck"
    
    // Arms
    case leftShoulder = "leftShoulder"
    case rightShoulder = "rightShoulder"
    case leftElbow = "leftElbow"
    case rightElbow = "rightElbow"
    case leftWrist = "leftWrist"
    case rightWrist = "rightWrist"
    
    // Body
    case leftHip = "leftHip"
    case rightHip = "rightHip"
    case root = "root"
    
    // Legs
    case leftKnee = "leftKnee"
    case rightKnee = "rightKnee"
    case leftAnkle = "leftAnkle"
    case rightAnkle = "rightAnkle"
    
    var displayName: String {
        switch self {
        case .nose: return "Hidung"
        case .leftEye: return "Mata kiri"
        case .rightEye: return "Mata kanan"
        case .leftEar: return "Telinga kiri"
        case .rightEar: return "Telinga kanan"
        case .neck: return "Leher"
        case .leftShoulder: return "Bahu kiri"
        case .rightShoulder: return "Bahu kanan"
        case .leftElbow: return "Siku kiri"
        case .rightElbow: return "Siku kanan"
        case .leftWrist: return "Pergelangan tangan kiri"
        case .rightWrist: return "Pergelangan tangan kanan"
        case .leftHip: return "Pinggul kiri"
        case .rightHip: return "Pinggul kanan"
        case .root: return "Tengah badan"
        case .leftKnee: return "Lutut kiri"
        case .rightKnee: return "Lutut kanan"
        case .leftAnkle: return "Pergelangan kaki kiri"
        case .rightAnkle: return "Pergelangan kaki kanan"
        }
    }
    
    // Mapping dari VNHumanBodyPoseObservation.JointName
    static func from(vnJoint: VNHumanBodyPoseObservation.JointName) -> JointName? {
        switch vnJoint {
        case .nose: return .nose
        case .leftEye: return .leftEye
        case .rightEye: return .rightEye
        case .leftEar: return .leftEar
        case .rightEar: return .rightEar
        case .neck: return .neck
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftElbow: return .leftElbow
        case .rightElbow: return .rightElbow
        case .leftWrist: return .leftWrist
        case .rightWrist: return .rightWrist
        case .leftHip: return .leftHip
        case .rightHip: return .rightHip
        case .root: return .root
        case .leftKnee: return .leftKnee
        case .rightKnee: return .rightKnee
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        default: return nil
        }
    }
}

// Model untuk informasi pose dalam jurus
struct JurusPose {
    let id: String
    let name: String
    let description: String
    let imageName: String
    var poseReference: PoseReference?
}

// Model untuk tracking progress latihan
struct TrainingProgress {
    var currentPoseIndex: Int = 0
    var completedPoses: Set<Int> = []
    var poseHoldStartTime: Date?
    var isHoldingCorrectPose: Bool = false
    
    mutating func startHoldingPose() {
        poseHoldStartTime = Date()
        isHoldingCorrectPose = true
    }
    
    mutating func stopHoldingPose() {
        poseHoldStartTime = nil
        isHoldingCorrectPose = false
    }
    
    var holdDuration: TimeInterval {
        guard let startTime = poseHoldStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
} 