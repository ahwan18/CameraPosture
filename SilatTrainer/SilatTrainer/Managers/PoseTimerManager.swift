import Foundation

protocol PoseTimerManagerDelegate: AnyObject {
    func poseTimerDidComplete()
    func poseTimerDidFail()
    func poseTimerDidUpdate(countdown: Int, progress: Double)
    func isPoseStillValid() -> Bool
}

class PoseTimerManager {
    weak var delegate: PoseTimerManagerDelegate?

    private var holdTimer: Timer?
    private var toleranceTimer: Timer?
    private var poseFailedTime: Date?

    private var isPaused: Bool = false
    private var pausedElapsedTime: Double = 0.0


    private let holdDuration: Double = 8.0
    private let poseTolerance: TimeInterval = 0.15
    private let checkInterval: Double = 0.1
    
    private var elapsedTime: Double = 0.0
    
    func startTimer() {
        guard holdTimer == nil else { 
            print("[PoseTimerManager] Timer sudah berjalan, tidak perlu memulai lagi")
            return 
        }
        
        print("[PoseTimerManager] Memulai timer")
        timerCompleted = false
        elapsedTime = 0.0
        pausedElapsedTime = 0.0
        isPaused = false
        poseFailedTime = nil
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func pauseTimer() {
        isPaused = true
        pausedElapsedTime = elapsedTime
        holdTimer?.invalidate()
        holdTimer = nil
        
        // Store the current state to resume from later
        delegate?.poseTimerDidUpdate(countdown: Int(holdDuration) - Int(elapsedTime), progress: elapsedTime / holdDuration)
    }
    
    func resumeTimer() {
        guard isPaused else { return }
        
        isPaused = false
        elapsedTime = pausedElapsedTime
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stopTimer() {
        print("[PoseTimerManager] Menghentikan timer: completed=\(timerCompleted)")
        holdTimer?.invalidate()
        holdTimer = nil
        toleranceTimer?.invalidate()
        toleranceTimer = nil
        elapsedTime = 0.0
        pausedElapsedTime = 0.0
        isPaused = false
        poseFailedTime = nil
    }

    private func tick() {
        guard let delegate = delegate, !isPaused else {
            return
        }

        if delegate.isPoseStillValid() {
            // Pose is correct, reset any failure tracking
            poseFailedTime = nil
            
            // Update progress
            elapsedTime += checkInterval
            let progress = elapsedTime / holdDuration
            let countdown = Int(holdDuration) - Int(elapsedTime)
            
            delegate.poseTimerDidUpdate(countdown: max(countdown, 0), progress: min(progress, 1.0))
            
            // Check for completion
            if elapsedTime >= holdDuration {
                print("[PoseTimerManager] Timer selesai, elapsed time = \(elapsedTime)")
                timerCompleted = true
                stopTimer()
                delegate.poseTimerDidComplete()
            }
        } else {
            // Pose became incorrect
            if poseFailedTime == nil {
                // First time we notice the failure, mark the time
                poseFailedTime = Date()
            } else {
                // Failure already noticed, check if tolerance is exceeded
                if Date().timeIntervalSince(poseFailedTime!) >= poseTolerance {
                    print("[PoseTimerManager] Pose tidak valid melebihi toleransi")
                    stopTimer()
                    delegate.poseTimerDidFail()
                }
            }
        }
    }
} 