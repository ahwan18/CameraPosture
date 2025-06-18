//
//  AudioFeedbackManager.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 17/06/25.
//

// Helpers/AudioFeedbackManager.swift
class AudioFeedbackManager {
    static let shared = AudioFeedbackManager()
    private var feedbackQueue: [String] = []
    private var isSpeaking = false
    
    func addFeedback(_ message: String) {
        feedbackQueue.append(message)
        processQueue()
    }
    
    private func processQueue() {
        guard !isSpeaking, let message = feedbackQueue.first else { return }
        isSpeaking = true
        
        VoiceHelper.shared.speak(message) { [weak self] in
            self?.isSpeaking = false
            self?.feedbackQueue.removeFirst()
            self?.processQueue()
        }
    }
}
