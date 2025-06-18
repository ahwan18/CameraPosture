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

// Helpers/VoiceHelper.swift
class VoiceHelper: NSObject {
    static let shared = VoiceHelper()
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenTime: Date?
    private let minimumTimeBetweenSpeeches: TimeInterval = 2.0
    private var completionHandler: (() -> Void)?
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        // Check if enough time has passed since last speech
        if let lastTime = lastSpokenTime,
           Date().timeIntervalSince(lastTime) < minimumTimeBetweenSpeeches {
            completion?()
            return
        }
        
        // Store completion handler
        self.completionHandler = completion
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Speak
        synthesizer.speak(utterance)
        lastSpokenTime = Date()
        
        print("Speaking: \(text)")
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension VoiceHelper: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completionHandler?()
        completionHandler = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completionHandler?()
        completionHandler = nil
    }
}
