import Foundation
import AVFoundation

class AudioFeedbackService: NSObject {
    static let shared = AudioFeedbackService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var lastFeedbackTime: Date?
    private var feedbackQueue: [String] = []
    private var isProcessingQueue = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func speak(_ text: String, isHighPriority: Bool = false) {
        // Check if enough time has passed since last feedback
        if let lastTime = lastFeedbackTime {
            let timeSinceLastFeedback = Date().timeIntervalSince(lastTime)
            if timeSinceLastFeedback < TrainingConfig.audioFeedbackDelay {
                // Too soon, add to queue if high priority
                if isHighPriority {
                    feedbackQueue.append(text)
                }
                return
            }
        }
        
        // Stop current speech if any for high priority messages
        if synthesizer.isSpeaking && isHighPriority {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "id-ID") // Indonesian
        utterance.rate = 0.5 // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9
        
        synthesizer.speak(utterance)
        lastFeedbackTime = Date()
    }
    
    func speakPoseInstruction(_ poseName: String) {
        speak("Lakukan pose \(poseName). Tahan selama 3 detik.", isHighPriority: true)
    }
    
    func speakCorrection(_ message: String) {
        speak(message, isHighPriority: false)
    }
    
    func speakEncouragement() {
        let encouragements = [
            "Bagus, pertahankan!",
            "Sempurna!",
            "Terus begitu!",
            "Mantap!"
        ]
        
        if let randomMessage = encouragements.randomElement() {
            speak(randomMessage, isHighPriority: false)
        }
    }
    
    func speakPoseCompleted() {
        speak("Pose selesai! Lanjut ke pose berikutnya.", isHighPriority: true)
    }
    
    func speakTrainingCompleted() {
        speak("Selamat! Anda telah menyelesaikan semua pose Jurus Satu. Luar biasa!", isHighPriority: true)
    }
    
    func speakWarning(_ message: String) {
        speak(message, isHighPriority: true)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        feedbackQueue.removeAll()
        isProcessingQueue = false
    }
    
    private func processQueue() {
        guard !isProcessingQueue && !feedbackQueue.isEmpty else { return }
        
        isProcessingQueue = true
        if let nextMessage = feedbackQueue.first {
            feedbackQueue.removeFirst()
            speak(nextMessage, isHighPriority: false)
        }
    }
}

extension AudioFeedbackService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isProcessingQueue = false
        
        // Process next item in queue after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.processQueue()
        }
    }
} 