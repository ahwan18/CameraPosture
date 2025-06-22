//
//  VoiceOutput.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 15/06/25.
//

//
//  VoiceHelper.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 15/06/25.
//

import Foundation
import AVFoundation

class VoiceHelper: VoiceFeedbackProtocol {
    static let shared = VoiceHelper()
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenTime: Date?
    private let minimumTimeBetweenSpeeches: TimeInterval = 0.5 // Minimum 0.5 seconds between speeches
    
    private init() {}
    
    func speak(_ text: String) {
        // Check if enough time has passed since last speech
        if let lastTime = lastSpokenTime,
           Date().timeIntervalSince(lastTime) < minimumTimeBetweenSpeeches {
            return
        }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID") // Indonesian voice
        utterance.rate = 0.5 // Slower rate for better clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Speak
        synthesizer.speak(utterance)
        lastSpokenTime = Date()
        
        print("Speaking: \(text)")
    }
    
    func provideFeedback(similarity: Double, for poseName: String) {
        let feedbackMessage: String
        
        if similarity > 0.9 {
            feedbackMessage = "Sangat bagus! Pose \(poseName) sempurna."
        } else if similarity > 0.7 {
            feedbackMessage = "Bagus! Pose \(poseName) hampir sempurna."
        } else if similarity > 0.5 {
            feedbackMessage = "Pose \(poseName) cukup baik, terus perbaiki."
        } else {
            feedbackMessage = "Coba sesuaikan pose \(poseName) Anda."
        }
        
        speak(feedbackMessage)
    }
    
    func provideJointCorrection(for joints: [String], in poseName: String) {
        if joints.isEmpty {
            speak("Posisi tubuh sudah tepat untuk pose \(poseName).")
            return
        }
        
        // Map joint names to Indonesian terms
        let jointTranslations: [String: String] = [
            "nose": "hidung",
            "neck": "leher",
            "rightShoulder": "bahu kanan",
            "leftShoulder": "bahu kiri",
            "rightElbow": "siku kanan",
            "leftElbow": "siku kiri",
            "rightWrist": "pergelangan tangan kanan",
            "leftWrist": "pergelangan tangan kiri",
            "rightHip": "pinggul kanan",
            "leftHip": "pinggul kiri",
            "rightKnee": "lutut kanan",
            "leftKnee": "lutut kiri",
            "rightAnkle": "pergelangan kaki kanan",
            "leftAnkle": "pergelangan kaki kiri"
        ]
        
        // Limit to maximum 3 joints to avoid too much feedback
        let limitedJoints = joints.prefix(3)
        let jointNames = limitedJoints.compactMap { jointTranslations[$0] }
        
        if jointNames.isEmpty {
            return
        }
        
        let jointsText = jointNames.joined(separator: ", ")
        speak("Sesuaikan posisi \(jointsText) Anda untuk pose \(poseName).")
    }
    
    func announceTrainingEvent(_ event: String) {
        switch event {
        case "start":
            speak("Latihan dimulai. Bersiaplah.")
        case "complete":
            speak("Pose berhasil. Bagus sekali!")
        case "rest":
            speak("Istirahat sejenak. Bersiaplah untuk pose berikutnya.")
        case "end":
            speak("Latihan selesai. Terima kasih atas usaha Anda.")
        default:
            speak(event)
        }
    }
}
