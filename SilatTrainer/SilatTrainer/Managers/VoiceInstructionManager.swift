//
//  VoiceInstructionManager.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 20/06/25.
//

//
//  VoiceInstructionManager.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on [Date]
//

import Foundation
import Vision

protocol VoiceInstructionManagerDelegate: AnyObject {
    func didStartVoiceInstruction()
    func didFinishVoiceInstruction()
}

class VoiceInstructionManager: ObservableObject {
    
    // MARK: - Dependencies
    private let voiceHelper: VoiceHelper
    weak var delegate: VoiceInstructionManagerDelegate?
    
    // MARK: - State
    @Published private(set) var isProcessingVoice: Bool = false
    
    // MARK: - Timing Control
    private var lastVoiceInstructionTime: Date = Date()
    private var lastCorrectionTime: Date = Date.distantPast
    
    // MARK: - Constants
    private let voiceInstructionInterval: TimeInterval = 4.0
    private let correctionGracePeriod: TimeInterval = 2.0
    
    // MARK: - Initialization
    init(voiceHelper: VoiceHelper = VoiceHelper.shared) {
        self.voiceHelper = voiceHelper
    }
    
    // MARK: - Public Methods
    
    /// Announce distance adjustment instruction
    func announceDistanceAdjustment() {
        guard canSpeak() else { return }
        
        speak("Pastikan seluruh tubuh terlihat")
    }
    
    /// Announce pose correction instruction
    func announcePoseCorrection(for joint: HumanBodyPoseObservation.JointName,
                               currentPoint: CGPoint,
                               targetPoint: CGPoint) {
        guard canSpeak(),
              canGiveCorrection() else { return }
        
        let jointIndonesian = jointNameToIndonesian(joint)
        var instruction = jointIndonesian
        
        // Determine vertical movement
        if currentPoint.y > targetPoint.y + 0.05 {
            instruction += " kurang naik"
        } else if currentPoint.y < targetPoint.y - 0.05 {
            instruction += " kurang turun"
        }
        
        speak(instruction)
        recordCorrectionTime()
    }
    
    /// Announce pose match success
    func announcePoseMatch() {
        guard canSpeak() else { return }
        
        speak("Pose benar, tahan posisi")
    }
    
    /// Announce pose failure
    func announcePoseFailure() {
        guard canSpeak() else { return }
        
        speak("Pose salah, ulangi lagi")
        recordInstructionTime()
    }
    
    /// Announce countdown number
    func announceCountdown(_ number: Int) {
        guard canSpeak() else { return }
        
        speak("\(number)")
    }
    
    /// Announce pose completion
    func announcePoseCompletion() {
        guard canSpeak() else { return }
        
        speak("Bagus! Lanjut ke gerakan berikutnya")
    }
    
    /// Announce session completion
    func announceSessionCompletion() {
        guard canSpeak() else { return }
        
        speak("Selamat! Semua gerakan telah diselesaikan")
    }
    
    /// Check if correction is allowed (not in grace period)
    func canGiveCorrection() -> Bool {
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        return timeSinceCorrection >= correctionGracePeriod
    }
    
    /// Check if we're in grace period after correction
    func isInGracePeriod() -> Bool {
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        return timeSinceCorrection < correctionGracePeriod
    }
    
    /// Record that a correction was given
    func recordCorrectionTime() {
        lastCorrectionTime = Date()
        recordInstructionTime()
    }
}

// MARK: - Private Methods
private extension VoiceInstructionManager {
    
    /// Check if we can speak (timing and processing constraints)
    func canSpeak() -> Bool {
        return !isProcessingVoice &&
               Date().timeIntervalSince(lastVoiceInstructionTime) >= voiceInstructionInterval
    }
    
    /// Execute speech with proper state management
    func speak(_ text: String) {
        isProcessingVoice = true
        delegate?.didStartVoiceInstruction()
        
        voiceHelper.speak(text)
        recordInstructionTime()
        
        // Reset processing state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isProcessingVoice = false
            self?.delegate?.didFinishVoiceInstruction()
        }
    }
    
    /// Record the time of voice instruction
    func recordInstructionTime() {
        lastVoiceInstructionTime = Date()
    }
    
    /// Convert joint name to Indonesian instruction
    func jointNameToIndonesian(_ jointName: HumanBodyPoseObservation.JointName) -> String {
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
}
