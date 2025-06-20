//
//  PoseMatchingManager.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 20/06/25.
//

import SwiftUI
import Vision
import Foundation

protocol PoseMatchingManagerDelegate: AnyObject {
    func didUpdateOptimalDistance(_ isOptimal: Bool)
    func didUpdatePoseMatch(_ isMatched: Bool)
    func didCalculateWorstJoint(_ joint: HumanBodyPoseObservation.JointName?, distance: Double)
}

class PoseMatchingManager: ObservableObject {
    
    // MARK: - Dependencies
    weak var delegate: PoseMatchingManagerDelegate?
    
    // MARK: - Constants
    private let poseMatchThreshold: Double = 0.12
    private let criticalJointThreshold: Double = 0.15
    private let proximityThreshold: Double = 0.05
    
    // MARK: - Required Joints for Optimal Distance
    private let requiredJoints: [HumanBodyPoseObservation.JointName] = [
        .nose, .neck,
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle
    ]
    
    // MARK: - Critical Joints
    private let criticalJoints: [HumanBodyPoseObservation.JointName] = [
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist
    ]
    
    // MARK: - Angle Configurations
    private let angleConfigurations: [(joint1: HumanBodyPoseObservation.JointName,
                                       joint2: HumanBodyPoseObservation.JointName,
                                       joint3: HumanBodyPoseObservation.JointName)] = [
        // Arm angles
        (.leftShoulder, .leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow, .rightWrist),
        // Shoulder line
        (.leftShoulder, .neck, .rightShoulder),
        // Leg angles
        (.leftHip, .leftKnee, .leftAnkle),
        (.rightHip, .rightKnee, .rightAnkle),
        // Torso angles
        (.neck, .leftShoulder, .leftHip),
        (.neck, .rightShoulder, .rightHip)
    ]
    
    // MARK: - Public Methods
    
    /// Check if user is at optimal distance based on joint visibility
    func checkOptimalDistance(detectedBodyParts: [HumanBodyPoseObservation.JointName: CGPoint]) -> Bool {
        let isOptimal = requiredJoints.allSatisfy { joint in
            detectedBodyParts[joint] != nil
        }
        
        delegate?.didUpdateOptimalDistance(isOptimal)
        return isOptimal
    }
    
    /// Check if current pose matches target pose
    func checkPoseMatch(
        detectedBodyParts: [HumanBodyPoseObservation.JointName: CGPoint],
        targetPose: PoseData
    ) -> Bool {
        var totalDistance: Double = 0
        var totalWeight: Double = 0
        var validJoints = 0
        
        // Get body dimensions for adaptive matching
        let userDimensions = calculateBodyDimensions(detectedBodyParts: detectedBodyParts)
        let targetReferences = getTargetPoseReferences(targetPose: targetPose)
        
        // Track the worst joint mismatch
        var worstJointDistance: Double = 0
        var criticalJointsMismatched = false
        
        // Process positional differences with adjusted weights
        for (jointName, detectedPoint) in detectedBodyParts {
            let jointKey = jointNameToKey(jointName)
            
            if let targetJoint = targetPose.joints[jointKey] {
                let targetPoint = CGPoint(x: targetJoint.x, y: targetJoint.y)
                
                // Apply adaptive scaling to target point if valid user dimensions
                let adjustedTargetPoint = userDimensions.valid ?
                    transformTargetPoint(
                        targetPoint,
                        userDimensions: userDimensions,
                        targetReferences: targetReferences
                    ) : targetPoint
                
                let dist = distance(detectedPoint, adjustedTargetPoint)
                
                // Track the worst joint mismatch for non-close joints
                if dist > worstJointDistance && getJointImportance(jointName: jointName, targetPose: targetPose) > 0.7 {
                    worstJointDistance = dist
                }
                
                // Check if critical joints are mismatched
                if criticalJoints.contains(jointName) && dist > criticalJointThreshold {
                    let jointImportance = getJointImportance(jointName: jointName, targetPose: targetPose)
                    if jointImportance > 0.7 {
                        criticalJointsMismatched = true
                    }
                }
                
                // Apply joint-specific weighting
                var weightedDist = dist
                let jointImportance = getJointImportance(jointName: jointName, targetPose: targetPose)
                
                if jointName == .leftWrist || jointName == .rightWrist {
                    weightedDist *= 1.3 * jointImportance
                } else if jointName == .leftElbow || jointName == .rightElbow {
                    weightedDist *= 1.2 * jointImportance
                } else {
                    weightedDist *= jointImportance
                }
                
                totalDistance += weightedDist
                totalWeight += jointImportance
                validJoints += 1
            }
        }
        
        guard validJoints > 0 else {
            delegate?.didUpdatePoseMatch(false)
            return false
        }
        
        // Calculate weighted average distance
        let averageDistance = (totalWeight > 0) ? totalDistance / totalWeight : totalDistance / Double(validJoints)
        
        // Check angles
        let averageAngleDifference = calculateAverageAngleDifference(
            detectedBodyParts: detectedBodyParts,
            targetPose: targetPose
        )
        
        // Determine if pose matches
        let poseMatches = averageDistance < poseMatchThreshold &&
                         worstJointDistance < (poseMatchThreshold * 2.5) &&
                         !criticalJointsMismatched &&
                         averageAngleDifference < 0.20
        
        delegate?.didUpdatePoseMatch(poseMatches)
        return poseMatches
    }
    
    /// Find the worst positioned joint for correction guidance
    func findWorstPositionedJoint(
        detectedBodyParts: [HumanBodyPoseObservation.JointName: CGPoint],
        targetPose: PoseData
    ) -> (joint: HumanBodyPoseObservation.JointName?, distance: Double) {
        var worstJoint: HumanBodyPoseObservation.JointName?
        var maxDistance: Double = 0
        
        for (jointName, detectedPoint) in detectedBodyParts {
            let jointKey = jointNameToKey(jointName)
            
            if let targetJoint = targetPose.joints[jointKey] {
                let targetPoint = CGPoint(x: targetJoint.x, y: targetJoint.y)
                let dist = distance(detectedPoint, targetPoint)
                
                if dist > maxDistance && dist > 0.15 {
                    maxDistance = dist
                    worstJoint = jointName
                }
            }
        }
        
        delegate?.didCalculateWorstJoint(worstJoint, distance: maxDistance)
        return (worstJoint, maxDistance)
    }
}

// MARK: - Private Helper Methods
extension PoseMatchingManager {
    
    /// Convert HumanBodyPoseObservation.JointName to poseData joint key
    func jointNameToKey(_ jointName: HumanBodyPoseObservation.JointName) -> String {
        switch jointName {
        case .nose: return "nose"
        case .neck: return "neck"
        case .leftShoulder: return "leftShoulder"
        case .rightShoulder: return "rightShoulder"
        case .leftElbow: return "leftElbow"
        case .rightElbow: return "rightElbow"
        case .leftWrist: return "leftWrist"
        case .rightWrist: return "rightWrist"
        case .leftHip: return "leftHip"
        case .rightHip: return "rightHip"
        case .leftKnee: return "leftKnee"
        case .rightKnee: return "rightKnee"
        case .leftAnkle: return "leftAnkle"
        case .rightAnkle: return "rightAnkle"
        default: return ""
        }
    }
    
    /// Calculate distance between two points
    func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculate body dimensions for adaptive pose matching
    func calculateBodyDimensions(detectedBodyParts: [HumanBodyPoseObservation.JointName: CGPoint]) -> (height: Double, center: CGPoint, width: Double, valid: Bool) {
        guard let neck = detectedBodyParts[.neck],
              let leftAnkle = detectedBodyParts[.leftAnkle] ?? detectedBodyParts[.rightAnkle] else {
            return (1.0, CGPoint(x: 0.5, y: 0.5), 0.3, false)
        }
        
        let bodyHeight = abs(neck.y - leftAnkle.y)
        
        var centerX: CGFloat = 0.5
        var centerY: CGFloat = 0.5
        
        if let leftHip = detectedBodyParts[.leftHip],
           let rightHip = detectedBodyParts[.rightHip] {
            centerX = (leftHip.x + rightHip.x) / 2
            centerY = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = detectedBodyParts[.leftHip] ?? detectedBodyParts[.rightHip] {
            centerX = singleHip.x
            centerY = singleHip.y
        } else if let neckPos = detectedBodyParts[.neck] {
            centerX = neckPos.x
            centerY = neckPos.y + 0.15
        }
        
        var bodyWidth: Double = 0.3
        if let leftShoulder = detectedBodyParts[.leftShoulder],
           let rightShoulder = detectedBodyParts[.rightShoulder] {
            let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
            bodyWidth = shoulderWidth
        }
        
        if let leftHip = detectedBodyParts[.leftHip],
           let rightHip = detectedBodyParts[.rightHip] {
            let hipWidth = abs(leftHip.x - rightHip.x)
            bodyWidth = max(bodyWidth, hipWidth)
        }
        
        return (bodyHeight, CGPoint(x: centerX, y: centerY), bodyWidth, true)
    }
    
    /// Get target pose reference dimensions
    func getTargetPoseReferences(targetPose: PoseData) -> (height: Double, center: CGPoint, width: Double) {
        var targetNeckY: CGFloat = 0.3
        var targetAnkleY: CGFloat = 0.9
        var targetCenter = CGPoint(x: 0.5, y: 0.5)
        
        if let neckJoint = targetPose.joints["neck"] {
            targetNeckY = neckJoint.y
        }
        
        if let leftAnkle = targetPose.joints["leftAnkle"] ?? targetPose.joints["rightAnkle"] {
            targetAnkleY = leftAnkle.y
        }
        
        let targetHeight = abs(targetAnkleY - targetNeckY)
        
        if let leftHip = targetPose.joints["leftHip"], let rightHip = targetPose.joints["rightHip"] {
            targetCenter.x = (leftHip.x + rightHip.x) / 2
            targetCenter.y = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = targetPose.joints["leftHip"] ?? targetPose.joints["rightHip"] {
            targetCenter.x = singleHip.x
            targetCenter.y = singleHip.y
        }
        
        var targetWidth: Double = 0.3
        if let leftShoulder = targetPose.joints["leftShoulder"],
           let rightShoulder = targetPose.joints["rightShoulder"] {
            let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
            targetWidth = shoulderWidth
        }
        
        if let leftHip = targetPose.joints["leftHip"],
           let rightHip = targetPose.joints["rightHip"] {
            let hipWidth = abs(leftHip.x - rightHip.x)
            targetWidth = max(targetWidth, hipWidth)
        }
        
        return (targetHeight, targetCenter, targetWidth)
    }
    
    /// Transform target pose point to match user's proportions
    func transformTargetPoint(
        _ targetPoint: CGPoint,
        userDimensions: (height: Double, center: CGPoint, width: Double, valid: Bool),
        targetReferences: (height: Double, center: CGPoint, width: Double)
    ) -> CGPoint {
        guard userDimensions.valid else { return targetPoint }
        
        let verticalScaleFactor = (targetReferences.height > 0.01) ? userDimensions.height / targetReferences.height : 1.0
        let widthRatio = (targetReferences.width > 0.01) ? userDimensions.width / targetReferences.width : 1.0
        let horizontalScaleFactor = (widthRatio + verticalScaleFactor) / 2.0
        
        let relativeX = targetPoint.x - targetReferences.center.x
        let relativeY = targetPoint.y - targetReferences.center.y
        
        let adjustedX = userDimensions.center.x + relativeX * horizontalScaleFactor
        let adjustedY = userDimensions.center.y + relativeY * verticalScaleFactor
        
        let boundedX = min(max(adjustedX, 0.01), 0.99)
        let boundedY = min(max(adjustedY, 0.01), 0.99)
        
        return CGPoint(x: boundedX, y: boundedY)
    }
    
    /// Calculate angle between three joints
    func calculateAngle(joint1: CGPoint?, joint2: CGPoint?, joint3: CGPoint?) -> Double? {
        guard let p1 = joint1, let p2 = joint2, let p3 = joint3 else { return nil }
        
        let v1x = p1.x - p2.x
        let v1y = p1.y - p2.y
        let v2x = p3.x - p2.x
        let v2y = p3.y - p2.y
        
        let dotProduct = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)
        
        if mag1 > 0.0001 && mag2 > 0.0001 {
            let cosAngle = dotProduct / (mag1 * mag2)
            let clampedCosAngle = max(-1, min(1, cosAngle))
            return Foundation.acos(clampedCosAngle)
        }
        
        return nil
    }
    
    /// Calculate average angle difference between user and target pose
    func calculateAverageAngleDifference(
        detectedBodyParts: [HumanBodyPoseObservation.JointName: CGPoint],
        targetPose: PoseData
    ) -> Double {
        var totalAngleDifference: Double = 0
        var validAngles = 0
        
        for angleConfig in angleConfigurations {
            let userJoint1 = detectedBodyParts[angleConfig.joint1]
            let userJoint2 = detectedBodyParts[angleConfig.joint2]
            let userJoint3 = detectedBodyParts[angleConfig.joint3]
            
            let joint1Key = jointNameToKey(angleConfig.joint1)
            let joint2Key = jointNameToKey(angleConfig.joint2)
            let joint3Key = jointNameToKey(angleConfig.joint3)
            
            // Skip angle check if any of the joints are too close in reference pose
            let skipAngleCheck = areJointsTooClose(joint1Key, joint2Key, targetPose: targetPose) ||
                                areJointsTooClose(joint2Key, joint3Key, targetPose: targetPose)
            
            if skipAngleCheck { continue }
            
            let targetJoint1 = targetPose.joints[joint1Key].map { CGPoint(x: $0.x, y: $0.y) }
            let targetJoint2 = targetPose.joints[joint2Key].map { CGPoint(x: $0.x, y: $0.y) }
            let targetJoint3 = targetPose.joints[joint3Key].map { CGPoint(x: $0.x, y: $0.y) }
            
            if let userAngle = calculateAngle(joint1: userJoint1, joint2: userJoint2, joint3: userJoint3),
               let targetAngle = calculateAngle(joint1: targetJoint1, joint2: targetJoint2, joint3: targetJoint3) {
                
                let angleDiff = abs(userAngle - targetAngle)
                let normalizedDiff = angleDiff / .pi
                
                totalAngleDifference += normalizedDiff
                validAngles += 1
            }
        }
        
        return validAngles > 0 ? totalAngleDifference / Double(validAngles) : 1.0
    }
    
    /// Check if two joints are too close in the target pose
    func areJointsTooClose(_ joint1Key: String, _ joint2Key: String, targetPose: PoseData) -> Bool {
        guard let joint1 = targetPose.joints[joint1Key],
              let joint2 = targetPose.joints[joint2Key] else {
            return false
        }
        
        let point1 = CGPoint(x: joint1.x, y: joint1.y)
        let point2 = CGPoint(x: joint2.x, y: joint2.y)
        let dist = distance(point1, point2)
        
        return dist < proximityThreshold
    }
    
    /// Get joint importance weight based on reference pose
    func getJointImportance(jointName: HumanBodyPoseObservation.JointName, targetPose: PoseData) -> Double {
        let jointKey = jointNameToKey(jointName)
        var importance: Double = 1.0
        
        if jointName == .leftHip || jointName == .rightHip {
            if areJointsTooClose("leftHip", "rightHip", targetPose: targetPose) {
                importance = 0.5
            }
        }
        
        if jointName == .leftShoulder || jointName == .rightShoulder {
            if areJointsTooClose("leftShoulder", "rightShoulder", targetPose: targetPose) {
                importance = 0.5
            }
        }
        
        if jointName == .leftWrist || jointName == .rightWrist {
            if areJointsTooClose("leftWrist", "rightWrist", targetPose: targetPose) {
                importance = 0.5
            }
        }
        
        if targetPose.poseId == "a3" && (jointName == .leftHip || jointName == .rightHip) {
            importance = 0.4
        }
        
        return importance
    }
}
