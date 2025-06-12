import Foundation
import Vision

// Model untuk menyimpan data pose yang akan diekspor ke JSON
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

// Model untuk editing pose di UI
struct EditablePose {
    var poseId: String
    var joints: [JointName: EditableJoint]
    var imageData: Data?
    
    func toPoseReference() -> PoseReference {
        var jointDict: [String: Joint] = [:]
        var ignoredJoints: [String] = []
        var importantJoints: [String] = []
        
        for (jointName, editableJoint) in joints {
            jointDict[jointName.rawValue] = Joint(
                x: editableJoint.normalizedPosition.x,
                y: editableJoint.normalizedPosition.y,
                confidence: editableJoint.confidence
            )
            
            switch editableJoint.status {
            case .ignored:
                ignoredJoints.append(jointName.rawValue)
            case .important:
                importantJoints.append(jointName.rawValue)
            case .normal:
                break
            }
        }
        
        return PoseReference(
            poseId: poseId,
            joints: jointDict,
            ignoredJoints: ignoredJoints,
            importantJoints: importantJoints
        )
    }
}

// Model untuk joint yang bisa diedit
struct EditableJoint {
    var normalizedPosition: CGPoint
    var confidence: CGFloat
    var status: JointStatus = .normal
}

// Status joint
enum JointStatus {
    case normal
    case ignored
    case important
}

// Enum untuk nama-nama joint sesuai Vision framework
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
        case .leftEye: return "Mata Kiri"
        case .rightEye: return "Mata Kanan"
        case .leftEar: return "Telinga Kiri"
        case .rightEar: return "Telinga Kanan"
        case .neck: return "Leher"
        case .leftShoulder: return "Bahu Kiri"
        case .rightShoulder: return "Bahu Kanan"
        case .leftElbow: return "Siku Kiri"
        case .rightElbow: return "Siku Kanan"
        case .leftWrist: return "Pergelangan Kiri"
        case .rightWrist: return "Pergelangan Kanan"
        case .leftHip: return "Pinggul Kiri"
        case .rightHip: return "Pinggul Kanan"
        case .root: return "Tengah Badan"
        case .leftKnee: return "Lutut Kiri"
        case .rightKnee: return "Lutut Kanan"
        case .leftAnkle: return "Pergelangan Kaki Kiri"
        case .rightAnkle: return "Pergelangan Kaki Kanan"
        }
    }
    
    // Mapping dari VNHumanBodyPoseObservation.JointName ke JointName kita
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