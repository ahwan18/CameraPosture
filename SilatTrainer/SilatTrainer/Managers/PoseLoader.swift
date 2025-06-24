//
//  PoseLoader.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import Vision

class PoseLoader: PoseServiceProtocol {
    static let shared = PoseLoader()
    
    private init() {}
    
    func loadPoses() -> [PoseData] {
        guard let url = Bundle.main.url(forResource: "poseData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([PoseData].self, from: data) else {
            print("Failed to load poseData.json")
            return []
        }
        return decoded
    }
    
    // For backward compatibility
    static func loadPose() -> [PoseData] {
        return PoseLoader.shared.loadPoses()
    }
    
    func analyzePoseSimilarity(detectedPose: [HumanBodyPoseObservation.JointName: CGPoint], against referencePose: PoseData) -> Double {
        // Simple implementation based on Euclidean distance
        var totalDistance: Double = 0.0
        var matchedJointCount = 0
        
        for (jointName, detectedPoint) in detectedPose {
            let jointNameString = String(describing: jointName)
            if let referencePoint = referencePose.keyPoints[jointNameString] {
                let dx = detectedPoint.x - referencePoint.x
                let dy = detectedPoint.y - referencePoint.y
                let distance = sqrt(dx*dx + dy*dy)
                totalDistance += distance
                matchedJointCount += 1
            }
        }
        
        if matchedJointCount == 0 {
            return 0.0
        }
        
        // Convert average distance to a similarity score (1.0 is perfect match, 0.0 is completely different)
        let averageDistance = totalDistance / Double(matchedJointCount)
        let maxPossibleDistance = 1.0 // Normalized coordinates are between 0 and 1
        let similarity = max(0.0, 1.0 - (averageDistance / maxPossibleDistance))
        
        return similarity
    }
    
    func getImproveableJoints(detectedPose: [HumanBodyPoseObservation.JointName: CGPoint], against referencePose: PoseData) -> [HumanBodyPoseObservation.JointName] {
        var jointsToImprove: [HumanBodyPoseObservation.JointName] = []
        let threshold = 0.1 // Threshold for joint position difference
        
        for (jointName, detectedPoint) in detectedPose {
            let jointNameString = String(describing: jointName)
            if let referencePoint = referencePose.keyPoints[jointNameString] {
                let dx = detectedPoint.x - referencePoint.x
                let dy = detectedPoint.y - referencePoint.y
                let distance = sqrt(dx*dx + dy*dy)
                
                if distance > threshold {
                    jointsToImprove.append(jointName)
                }
            }
        }
        
        return jointsToImprove
    }
}
