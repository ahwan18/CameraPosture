// VoiceHelper.swift - Versi yang diperbaiki
import Foundation
import AVFoundation

class VoiceHelper: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = VoiceHelper()
    private let synthesizer = AVSpeechSynthesizer()
    private var onComplete: (() -> Void)?
    private(set) var isProcessingVoice: Bool = false
    private var lastSpokenTime: Date?
    private let minimumTimeBetweenSpeeches: TimeInterval = 0.5
    
    private override init() {
        super.init()
        self.synthesizer.delegate = self
    }
    
    //  - Delegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isProcessingVoice = false
            self.onComplete?()
            self.onComplete = nil
        }
    }
    
    //  - Public Methods
    func speak(_ text: String, interrupt: Bool = false, completion: (() -> Void)? = nil) {
        // Check if enough time has passed since last speech (if not interrupting)
        if !interrupt, let lastTime = lastSpokenTime,
           Date().timeIntervalSince(lastTime) < minimumTimeBetweenSpeeches {
            completion?()
            return
        }
        
        // Stop current speech if interrupting
        if synthesizer.isSpeaking {
            if interrupt {
                synthesizer.stopSpeaking(at: .immediate)
            } else {
                completion?()
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
        lastSpokenTime = Date()
        
        print("Speaking: \(text)")
    }
    
}
