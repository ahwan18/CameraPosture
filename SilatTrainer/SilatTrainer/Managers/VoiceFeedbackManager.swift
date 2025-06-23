import Foundation
import AVFoundation
import Vision
import CoreGraphics

class VoiceFeedbackManager: VoiceFeedbackProtocol {
    private var lastCorrectionTime: Date = Date.distantPast
    private let voiceInstructionInterval: TimeInterval = 4.0
    private weak var poseViewModel: PoseEstimationViewModel?
    private let poseData: [PoseData]
    
    init(poseViewModel: PoseEstimationViewModel, poseData: [PoseData]) {
            self.poseViewModel = poseViewModel
            self.poseData = poseData
        }
    
    func speak(_ text: String, interrupt: Bool, completion: (() -> Void)? = nil) {
            VoiceHelper.shared.speak(text, interrupt: interrupt, completion: completion)
        }

    //  - Simple Announcers (tanpa completion)
    func announceDistance(isOptimal: Bool, wasOptimal: Bool) {
        if !VoiceHelper.shared.isProcessingVoice, !isOptimal, wasOptimal {
            VoiceHelper.shared.speak("Pastikan seluruh tubuh terlihat", interrupt: false)
        }
    }
    
    func announcePoseMatch() {
        VoiceHelper.shared.speak("Pose benar, tahan posisi", interrupt: true)
    }
    
    func announceHoldCountdown(second: Int) {
        VoiceHelper.shared.speak("\(second)", interrupt: false)
    }
    
    func announcePoseFailure() {
        VoiceHelper.shared.speak("Pose salah, ulangi lagi", interrupt: true)
        lastCorrectionTime = Date()
    }
    
    func announcePoseCompletion(isLastPose: Bool) {
        let text = isLastPose ? "Selamat!" : "Bagus! Lanjut ke gerakan berikutnya"
        VoiceHelper.shared.speak(text, interrupt: true)
    }
    
    func announceTrainingEvent(_ event: String) {
        switch event {
        case "start":
            speak("Latihan dimulai", interrupt: true)
        case "end":
            speak("Latihan selesai", interrupt: true)
        case "rest":
            speak("Istirahat sejenak, bersiap untuk gerakan berikutnya", interrupt: true)
        default:
            speak(event, interrupt: true)
        }
    }
    
    func provideFeedback(similarity: Double, for poseName: String) {
        if similarity > 0.85 {
            speak("Gerakan bagus", interrupt: false)
        } else if similarity > 0.7 {
            speak("Gerakan cukup baik, pertahankan", interrupt: false)
        } else {
            speak("Coba sesuaikan posisi tubuh", interrupt: false)
        }
    }
    
    func provideJointCorrection(for joints: [String], in poseName: String) {
        guard !joints.isEmpty else { return }
        
        if joints.count == 1 {
            speak("Sesuaikan posisi \(humanReadableJointName(joints[0]))", interrupt: true)
        } else if joints.count <= 3 {
            let jointNames = joints.map { humanReadableJointName($0) }.joined(separator: ", ")
            speak("Sesuaikan \(jointNames)", interrupt: true)
        } else {
            speak("Coba sesuaikan posisi tubuh secara keseluruhan", interrupt: true)
        }
        
        lastCorrectionTime = Date()
    }
    
    func giveJointCorrection(isPoseMatched: Bool, currentTargetPose: PoseData) {
        guard let poseViewModel = poseViewModel, !isPoseMatched, Date().timeIntervalSince(lastCorrectionTime) >= voiceInstructionInterval else { return }
        let detectedBodyParts = poseViewModel.detectedBodyParts
        var worstJoint: HumanBodyPoseObservation.JointName?
        var maxDistance: Double = 0

        for (jointName, detectedPoint) in detectedBodyParts {
            let jointKey = PoseMatcher.jointNameToKey(jointName)
            if let targetJoint = currentTargetPose.joints[jointKey] {
                let dist = distance(detectedPoint, CGPoint(x: targetJoint.x, y: targetJoint.y))
                if dist > maxDistance {
                    maxDistance = dist
                    worstJoint = jointName
                }
            }
        }
        
        if let joint = worstJoint {
            if let targetJoint = currentTargetPose.joints[PoseMatcher.jointNameToKey(joint)], let currentPoint = detectedBodyParts[joint] {
                var instruction = jointNameToIndonesian(joint)
                if currentPoint.y > targetJoint.y + 0.05 {
                    instruction += " kurang naik"
                } else if currentPoint.y < targetJoint.y - 0.05 {
                    instruction += " kurang turun"
                }
                if instruction != jointNameToIndonesian(joint) {
                    VoiceHelper.shared.speak(instruction, interrupt: true)
                    lastCorrectionTime = Date()
                }
            }
        }
    }
    
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
    }

    private func jointNameToIndonesian(_ jointName: HumanBodyPoseObservation.JointName) -> String {
        switch jointName {
        case .nose: return "hidung"
        case .neck: return "leher"
        case .leftShoulder: return "bahu kanan"
        case .rightShoulder: return "bahu kiri"
        case .leftElbow: return "siku kanan"
        case .rightElbow: return "siku kiri"
        case .leftWrist: return "pergelangan tangan kanan"
        case .rightWrist: return "pergelangan tangan kiri"
        case .leftHip: return "pinggul kanan"
        case .rightHip: return "pinggul kiri"
        case .leftKnee: return "lutut kanan"
        case .rightKnee: return "lutut kiri"
        case .leftAnkle: return "pergelangan kaki kanan"
        case .rightAnkle: return "pergelangan kaki kiri"
        default: return ""
        }
    }
    
    private func humanReadableJointName(_ jointString: String) -> String {
        // Convert technical joint names to user-friendly Indonesian names
        switch jointString.lowercased() {
        case "nose": return "hidung"
        case "neck": return "leher"
        case "leftshoulder": return "bahu kanan"
        case "rightshoulder": return "bahu kiri"
        case "leftelbow": return "siku kanan"
        case "rightelbow": return "siku kiri"
        case "leftwrist": return "pergelangan tangan kanan"
        case "rightwrist": return "pergelangan tangan kiri"
        case "lefthip": return "pinggul kanan"
        case "righthip": return "pinggul kiri"
        case "leftknee": return "lutut kanan"
        case "rightknee": return "lutut kiri"
        case "leftankle": return "pergelangan kaki kanan"
        case "rightankle": return "pergelangan kaki kiri"
        default: return jointString
        }
    }
}
