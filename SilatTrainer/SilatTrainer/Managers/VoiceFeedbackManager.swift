import Foundation
import AVFoundation
import Vision
import CoreGraphics

class VoiceFeedbackManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var onComplete: (() -> Void)?
    private(set) var isProcessingVoice: Bool = false
    private var lastCorrectionTime: Date = Date.distantPast
    
    private let voiceInstructionInterval: TimeInterval = 4.0
    private weak var poseViewModel: PoseEstimationViewModel?
    private let poseData: [PoseData]
    
    init(poseViewModel: PoseEstimationViewModel, poseData: [PoseData]) {
        self.poseViewModel = poseViewModel
        self.poseData = poseData
        super.init()
        self.synthesizer.delegate = self
    }

    // MARK: - Delegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isProcessingVoice = false
            self.onComplete?()
            self.onComplete = nil
        }
    }
    
    // MARK: - Public Speak Method (satu-satunya yang perlu completion)
    public func speak(_ text: String, interrupt: Bool, completion: (() -> Void)? = nil) {
        if synthesizer.isSpeaking {
            if interrupt {
                synthesizer.stopSpeaking(at: .immediate)
            } else {
                completion?() // Jika tidak boleh menginterupsi, langsung jalankan completion.
                return
            }
        }
        
        self.onComplete = completion
        isProcessingVoice = true
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }

    // MARK: - Simple Announcers (tanpa completion)
    func announceDistance(isOptimal: Bool, wasOptimal: Bool) {
        if !isProcessingVoice, !isOptimal, wasOptimal {
            speak("Pastikan seluruh tubuh terlihat", interrupt: false)
        }
    }
    
    func announcePoseMatch() {
        speak("Pose benar, tahan posisi", interrupt: true)
    }
    
    func announceHoldCountdown(second: Int) {
        speak("\(second)", interrupt: false)
    }
    
    func announcePoseFailure() {
        speak("Pose salah, ulangi lagi", interrupt: true)
        lastCorrectionTime = Date()
    }
    
    func announcePoseCompletion(isLastPose: Bool) {
        let text = isLastPose ? "Selamat!" : "Bagus! Lanjut ke gerakan berikutnya"
        speak(text, interrupt: true)
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
                    speak(instruction, interrupt: true)
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
        case .nose: "hidung"
        case .neck: "leher"
        case .leftShoulder: "bahu kanan"
        case .rightShoulder: "bahu kiri"
        case .leftElbow: "siku kanan"
        case .rightElbow: "siku kiri"
        case .leftWrist: "pergelangan tangan kanan"
        case .rightWrist: "pergelangan tangan kiri"
        case .leftHip: "pinggul kanan"
        case .rightHip: "pinggul kiri"
        case .leftKnee: "lutut kanan"
        case .rightKnee: "lutut kiri"
        case .leftAnkle: "pergelangan kaki kanan"
        case .rightAnkle: "pergelangan kaki kiri"
        default: ""
        }
    }
}
