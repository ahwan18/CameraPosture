//
//  PoseProgressManager.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 20/06/25.
//

import Foundation

protocol PoseProgressManagerDelegate: AnyObject {
    func didUpdateCurrentPose(_ poseIndex: Int)
    func didStartPoseTransition()
    func didFinishPoseTransition()
    func didCompleteAllPoses()
}

class PoseProgressManager: ObservableObject {
    
    // MARK: - Dependencies
    weak var delegate: PoseProgressManagerDelegate?
    
    // MARK: - Published State
    @Published private(set) var currentPoseIndex: Int = 0
    @Published private(set) var showPoseTransition: Bool = false
    @Published private(set) var showCompletionMessage: Bool = false
    @Published private(set) var totalPoses: Int = 0
    
    // MARK: - Private State
    private let poseData: [PoseData]
    
    // MARK: - Initialization
    init(poseData: [PoseData]) {
        self.poseData = poseData
        self.totalPoses = poseData.count
    }
    
    // MARK: - Public Methods
    
    /// Get the current target pose
    var currentTargetPose: PoseData? {
        guard currentPoseIndex < poseData.count else { return nil }
        return poseData[currentPoseIndex]
    }
    
    /// Check if all poses are completed
    var isLastPose: Bool {
        return currentPoseIndex >= poseData.count - 1
    }
    
    /// Get current pose display text
    var currentPoseDisplayText: String {
        return "A\(currentPoseIndex + 1) / A\(totalPoses)"
    }
    
    /// Move to next pose
    func moveToNextPose() {
        guard currentPoseIndex < poseData.count - 1 else {
            // All poses completed
            completeAllPoses()
            return
        }
        
        // Show transition screen
        showPoseTransition = true
        delegate?.didStartPoseTransition()
        
        // Wait for transition, then move to next pose
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            
            self.currentPoseIndex += 1
            self.showPoseTransition = false
            
            self.delegate?.didUpdateCurrentPose(self.currentPoseIndex)
            self.delegate?.didFinishPoseTransition()
        }
    }
    
    /// Reset to first pose
    func resetToFirstPose() {
        currentPoseIndex = 0
        showPoseTransition = false
        showCompletionMessage = false
        
        delegate?.didUpdateCurrentPose(currentPoseIndex)
    }
    
    /// Skip to specific pose (for testing or navigation)
    func skipToPose(_ poseIndex: Int) {
        guard poseIndex >= 0 && poseIndex < poseData.count else { return }
        
        currentPoseIndex = poseIndex
        showPoseTransition = false
        showCompletionMessage = false
        
        delegate?.didUpdateCurrentPose(currentPoseIndex)
    }
    
    /// Get pose at specific index
    func getPose(at index: Int) -> PoseData? {
        guard index >= 0 && index < poseData.count else { return nil }
        return poseData[index]
    }
    
    /// Get next pose (for preview purposes)
    var nextPose: PoseData? {
        let nextIndex = currentPoseIndex + 1
        guard nextIndex < poseData.count else { return nil }
        return poseData[nextIndex]
    }
}

// MARK: - Private Methods
private extension PoseProgressManager {
    
    /// Complete all poses in the session
    func completeAllPoses() {
        showCompletionMessage = true
        delegate?.didCompleteAllPoses()
    }
}
