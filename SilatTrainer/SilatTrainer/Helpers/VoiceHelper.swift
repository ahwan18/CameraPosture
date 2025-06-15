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

class VoiceHelper {
    static let shared = VoiceHelper()
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenTime: Date?
    private let minimumTimeBetweenSpeeches: TimeInterval = 2.0 // Minimum 2 seconds between speeches
    
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
}
