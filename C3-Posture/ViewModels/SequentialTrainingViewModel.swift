import SwiftUI
import Combine
import Foundation

// MARK: - Sequential Training ViewModel

class SequentialTrainingViewModel: ObservableObject, SequentialTrainingDelegate {
    
    // MARK: - Published Properties
    
    @Published var trainingSession: TrainingSession?
    @Published var holdTimer: HoldTimer = HoldTimer()
    @Published var isTrainingActive: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    
    var currentPose: Posture? {
        trainingSession?.currentPose
    }
    
    var currentPoseIndex: Int {
        trainingSession?.currentPoseIndex ?? 0
    }
    
    var totalPoses: Int {
        trainingSession?.totalPoses ?? 0
    }
    
    var isCompleted: Bool {
        trainingSession?.isCompleted ?? false
    }
    
    var progress: Double {
        trainingSession?.progress ?? 0.0
    }
    
    var isHolding: Bool {
        holdTimer.isActive
    }
    
    var holdTimeRemaining: Double {
        holdTimer.remainingTime
    }
    
    var holdProgress: Double {
        holdTimer.progress
    }
    
    // MARK: - Private Properties
    
    private let postureService: PostureServiceProtocol
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let timerInterval: TimeInterval = 0.1
    
    // MARK: - Callbacks
    
    var onPoseChanged: ((Posture) -> Void)?
    var onTrainingCompleted: (() -> Void)?
    var onPositioningLost: (() -> Void)?
    
    // MARK: - Initialization
    
    init(postureService: PostureServiceProtocol = PostureService.shared) {
        self.postureService = postureService
    }
    
    deinit {
        stopTraining()
    }
    
    // MARK: - Public Methods
    
    func startTraining() {
        let postures = postureService.getAllPostures()
        
        guard !postures.isEmpty else {
            errorMessage = "No postures available for training"
            return
        }
        
        trainingSession = TrainingSession(poses: postures)
        isTrainingActive = true
        holdTimer = HoldTimer()
        
        // Notify about the first pose
        if let currentPose = currentPose {
            onPoseChanged?(currentPose)
        }
        
        print("SequentialTrainingViewModel: Started training with \(totalPoses) poses")
    }
    
    func stopTraining() {
        timer?.invalidate()
        timer = nil
        isTrainingActive = false
        holdTimer.stop()
        trainingSession = nil
        
        print("SequentialTrainingViewModel: Training stopped")
    }
    
    func restartTraining() {
        stopTraining()
        startTraining()
    }
    
    func updatePoseMatchStatus(_ isMatched: Bool) {
        guard isTrainingActive, !isCompleted else { 
            print("⚠️ UpdatePoseMatch ignored - Active: \(isTrainingActive), Completed: \(isCompleted)")
            return 
        }
        
        print("📊 Pose Match Update: \(isMatched ? "✅ MATCHED" : "❌ NOT MATCHED") - Timer Active: \(holdTimer.isActive)")
        
        if isMatched && !holdTimer.isActive {
            // User matched the pose and we're not already holding - start the timer
            print("🚀 Starting hold timer - user matched pose!")
            startHoldTimer()
        } else if !isMatched && holdTimer.isActive {
            // User lost the pose while holding - reset the timer completely
            resetHoldTimer()
            print("🔄 Pose match lost - timer reset!")
        } else if isMatched && holdTimer.isActive {
            // User is still matching and holding - timer continues
            print("⏳ Pose still matched - timer continues...")
        } else if !isMatched && !holdTimer.isActive {
            // User is not matching and not holding - ensure timer stays reset
            print("⏸️ Pose not matched - timer stays reset")
            resetHoldTimer()
        }
    }
    
    // MARK: - Private Methods
    
    private func startHoldTimer() {
        // Stop any existing timer first
        timer?.invalidate()
        
        holdTimer.start()
        
        print("SequentialTrainingViewModel: Starting hold timer for \(holdTimer.requiredDuration) seconds")
        
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let completed = self.holdTimer.tick(by: self.timerInterval)
            
            if completed {
                timer.invalidate()
                print("🎯 Hold timer completed successfully! Moving to next pose...")
                self.completeCurrentPose()
            } else {
                // Occasionally log progress
                if Int(self.holdTimer.remainingTime * 10) % 10 == 0 {
                    print("⏰ Hold progress: \(String(format: "%.1f", self.holdTimer.requiredDuration - self.holdTimer.remainingTime))/\(self.holdTimer.requiredDuration)s")
                }
            }
        }
    }
    
    private func resetHoldTimer() {
        timer?.invalidate()
        timer = nil
        holdTimer.stop()
        print("SequentialTrainingViewModel: Hold timer reset")
    }
    
    private func completeCurrentPose() {
        guard var session = trainingSession else { return }
        
        resetHoldTimer()
        session.moveToNextPose()
        trainingSession = session
        
        if session.isCompleted {
            // Training completed
            isTrainingActive = false
            onTrainingCompleted?()
            print("SequentialTrainingViewModel: Training completed!")
        } else {
            // Move to next pose after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                if let currentPose = self?.currentPose {
                    self?.onPoseChanged?(currentPose)
                    print("SequentialTrainingViewModel: Moved to pose \(self?.currentPoseIndex ?? 0 + 1)")
                }
            }
        }
    }
    
    // MARK: - SequentialTrainingDelegate
    
    func userLeftPositioningBox() {
        print("SequentialTrainingViewModel: User left positioning box for extended period - resetting training")
        
        // Reset current training state but don't immediately restart
        resetHoldTimer()
        
        // Reset to first pose but don't start a new training session immediately
        if var session = trainingSession {
            session.resetToFirstPose()
            trainingSession = session
            
            // Notify about returning to first pose
            if let firstPose = currentPose {
                onPoseChanged?(firstPose)
            }
        }
        
        // Notify callback if needed
        onPositioningLost?()
    }
    
    func positioningCompleted() {
        print("SequentialTrainingViewModel: Positioning completed - starting training")
        
        // Now start the training session
        startTraining()
    }
}

// MARK: - Training State

enum TrainingState {
    case idle
    case active
    case holding
    case completed
} 