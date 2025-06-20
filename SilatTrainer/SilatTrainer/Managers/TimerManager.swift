//
//  TimerManager.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 20/06/25.
//

import Foundation

protocol TimerManagerDelegate: AnyObject {
    func didUpdateHoldProgress(_ progress: Double)
    func didUpdateCountdown(_ value: Int)
    func didCompleteHoldTimer()
    func didFailHoldTimer()
    func shouldAnnounceCountdown(_ number: Int)
}

class TimerManager: ObservableObject {
    
    // MARK: - Dependencies
    weak var delegate: TimerManagerDelegate?
    
    // MARK: - Published State
    @Published private(set) var holdProgress: Double = 0.0
    @Published private(set) var countdownValue: Int = 8
    @Published private(set) var isHolding: Bool = false
    
    // MARK: - Private State
    private var holdTimer: Timer?
    private var toleranceTimer: Timer?
    private var poseFailedTime: Date?
    
    // MARK: - Constants
    private let holdDuration: Double = 8.0
    private let poseTolerance: TimeInterval = 0.15
    private let checkInterval: Double = 0.1
    
    // MARK: - Public Methods
    
    /// Start the hold timer for pose validation
    func startHoldTimer() {
        // Reset state
        holdProgress = 0.0
        countdownValue = 8
        isHolding = true
        poseFailedTime = nil
        
        // Stop any existing timer
        stopHoldTimer()
        
        // Announce initial countdown
        delegate?.shouldAnnounceCountdown(8)
        
        var elapsedTime: Double = 0.0
        var lastAnnouncedSecond: Int = 8
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Update elapsed time and progress
            elapsedTime += self.checkInterval
            self.holdProgress = elapsedTime / self.holdDuration
            
            // Update countdown value
            let currentSecond = Int(self.holdDuration) - Int(elapsedTime)
            self.countdownValue = max(currentSecond, 1)
            
            // Notify delegate of progress update
            self.delegate?.didUpdateHoldProgress(self.holdProgress)
            self.delegate?.didUpdateCountdown(self.countdownValue)
            
            // Announce each second
            if currentSecond < lastAnnouncedSecond && currentSecond >= 1 {
                lastAnnouncedSecond = currentSecond
                self.delegate?.shouldAnnounceCountdown(currentSecond)
            }
            
            // Check for completion
            if elapsedTime >= self.holdDuration {
                timer.invalidate()
                self.completeHoldTimer()
            }
        }
    }
    
    /// Stop the hold timer
    func stopHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        toleranceTimer?.invalidate()
        toleranceTimer = nil
        
        holdProgress = 0.0
        countdownValue = 8
        isHolding = false
        poseFailedTime = nil
    }
    
    /// Reset hold timer due to pose failure
    func resetHoldTimer() {
        stopHoldTimer()
        delegate?.didFailHoldTimer()
    }
    
    /// Handle pose validation during hold timer
    func validatePoseForHoldTimer(isPoseValid: Bool) {
        guard isHolding else { return }
        
        if isPoseValid {
            // Pose is valid, reset tolerance tracking
            poseFailedTime = nil
            toleranceTimer?.invalidate()
            toleranceTimer = nil
        } else {
            // Pose became invalid
            if poseFailedTime == nil {
                // Start tolerance timer
                poseFailedTime = Date()
                startToleranceTimer()
            }
        }
    }
    
    /// Check if currently in tolerance period
    func isInTolerancePeriod() -> Bool {
        guard let failTime = poseFailedTime else { return false }
        return Date().timeIntervalSince(failTime) < poseTolerance
    }
}

// MARK: - Private Methods
private extension TimerManager {
    
    /// Complete the hold timer successfully
    func completeHoldTimer() {
        holdProgress = 1.0
        isHolding = false
        delegate?.didCompleteHoldTimer()
        stopHoldTimer()
    }
    
    /// Start tolerance timer for pose validation
    func startToleranceTimer() {
        toleranceTimer?.invalidate()
        
        toleranceTimer = Timer.scheduledTimer(withTimeInterval: poseTolerance, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Tolerance period expired, reset hold timer
            self.resetHoldTimer()
        }
    }
}
