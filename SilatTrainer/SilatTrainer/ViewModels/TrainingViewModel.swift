//
//  TrainingViewModel.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 17/06/25.
//

import Foundation

@Observable
class TrainingViewModel {
    var currentPoseIndex = 0
    var holdTimer: Timer?
    var holdProgress: Double = 0
    var isHolding: Bool = false
    let holdDuration: TimeInterval = 3.0
    
    let poses: [PoseData]
    var currentFeedbacks: [PoseComparison.Feedback] = []
    
    init() {
        self.poses = PoseLoader.loadPose()
    }
    
    func startHoldTimer() {
        isHolding = true
        holdProgress = 0
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.holdProgress += 0.1 / self.holdDuration
            if self.holdProgress >= 1.0 {
                self.completePose()
            }
        }
    }
    
    func resetHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdProgress = 0
    }
    
    var onComplete: (() -> Void)?
    
    func completePose() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        currentPoseIndex += 1
        if currentPoseIndex >= poses.count {
            // Selesai semua pose
            onComplete?() 
        }
    }
    
}
