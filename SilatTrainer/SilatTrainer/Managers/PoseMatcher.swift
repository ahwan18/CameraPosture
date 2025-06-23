import Foundation
import CoreGraphics
import Vision

class PoseMatcher: PoseMatcherProtocol {
    private let poseData: [PoseData]
    private weak var poseViewModel: PoseEstimationViewModel?
    
    private let poseMatchThreshold: Double = 0.12

    init(poseData: [PoseData], poseViewModel: PoseEstimationViewModel) {
        self.poseData = poseData
        self.poseViewModel = poseViewModel
    }

    func checkPoseMatch(currentPoseIndex: Int) -> Bool {
        guard let poseViewModel = self.poseViewModel, currentPoseIndex < poseData.count else { return false }
        
        let targetPose = poseData[currentPoseIndex]
        var totalDistance: Double = 0
        var totalWeight: Double = 0
        var validJoints = 0
        
        let userDimensions = calculateBodyDimensions()
        let targetReferences = getTargetPoseReferences(currentPoseIndex: currentPoseIndex)
        
        var worstJointDistance: Double = 0
        var criticalJointsMismatched = false
        
        let criticalJoints: [HumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist
        ]
        
        let criticalJointThreshold: Double = 0.15
        
        for (jointName, detectedPoint) in poseViewModel.detectedBodyParts {
            let jointKey = PoseMatcher.jointNameToKey(jointName)
            
            if let targetJoint = targetPose.joints[jointKey] {
                let targetPoint = CGPoint(x: targetJoint.x, y: targetJoint.y)
                
                let adjustedTargetPoint = userDimensions.valid ?
                    transformTargetPoint(targetPoint, userDimensions: userDimensions, targetReferences: targetReferences, currentPoseIndex: currentPoseIndex) : targetPoint
                
                let dist = distance(detectedPoint, adjustedTargetPoint)
                
                if dist > worstJointDistance && getJointImportance(jointName: jointName, targetPose: targetPose) > 0.7 {
                    worstJointDistance = dist
                }
                
                if criticalJoints.contains(jointName) && dist > criticalJointThreshold {
                    if getJointImportance(jointName: jointName, targetPose: targetPose) > 0.7 {
                        criticalJointsMismatched = true
                    }
                }
                
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
        
        guard validJoints > 0 else { return false }
        
        let averageDistance = (totalWeight > 0) ? totalDistance / totalWeight : totalDistance / Double(validJoints)
        
        var totalAngleDifference: Double = 0
        var validAngles = 0
        
        let angleConfigurations: [(joint1: HumanBodyPoseObservation.JointName, joint2: HumanBodyPoseObservation.JointName, joint3: HumanBodyPoseObservation.JointName)] = [
            (.leftShoulder, .leftElbow, .leftWrist), (.rightShoulder, .rightElbow, .rightWrist),
            (.leftShoulder, .neck, .rightShoulder), (.leftHip, .leftKnee, .leftAnkle),
            (.rightHip, .rightKnee, .rightAnkle), (.neck, .leftShoulder, .leftHip),
            (.neck, .rightShoulder, .rightHip)
        ]
        
        for angleConfig in angleConfigurations {
            let userJoint1 = poseViewModel.detectedBodyParts[angleConfig.joint1]
            let userJoint2 = poseViewModel.detectedBodyParts[angleConfig.joint2]
            let userJoint3 = poseViewModel.detectedBodyParts[angleConfig.joint3]
            
            let joint1Key = PoseMatcher.jointNameToKey(angleConfig.joint1)
            let joint2Key = PoseMatcher.jointNameToKey(angleConfig.joint2)
            let joint3Key = PoseMatcher.jointNameToKey(angleConfig.joint3)
            
            let skipAngleCheck = areJointsTooClose(joint1Key, joint2Key, targetPose: targetPose) || areJointsTooClose(joint2Key, joint3Key, targetPose: targetPose)
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
                
                if (angleConfig.joint2 == .leftElbow || angleConfig.joint2 == .rightElbow) && normalizedDiff > 0.25 {
                    criticalJointsMismatched = true
                }
            }
        }
        
        let averageAngleDifference = validAngles > 0 ? totalAngleDifference / Double(validAngles) : 1.0
        
        return averageDistance < poseMatchThreshold &&
               worstJointDistance < (poseMatchThreshold * 2.5) &&
               !criticalJointsMismatched &&
               averageAngleDifference < 0.20
    }
    
    //  - Helper Functions
    
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateBodyDimensions() -> (height: Double, center: CGPoint, width: Double, valid: Bool) {
        guard let poseViewModel = self.poseViewModel,
              let neck = poseViewModel.detectedBodyParts[.neck],
              let leftAnkle = poseViewModel.detectedBodyParts[.leftAnkle] ?? poseViewModel.detectedBodyParts[.rightAnkle] else {
            return (1.0, CGPoint(x: 0.5, y: 0.5), 0.3, false)
        }
        
        let bodyHeight = abs(neck.y - leftAnkle.y)
        var centerX: CGFloat = 0.5, centerY: CGFloat = 0.5
        
        if let leftHip = poseViewModel.detectedBodyParts[.leftHip], let rightHip = poseViewModel.detectedBodyParts[.rightHip] {
            centerX = (leftHip.x + rightHip.x) / 2
            centerY = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = poseViewModel.detectedBodyParts[.leftHip] ?? poseViewModel.detectedBodyParts[.rightHip] {
            centerX = singleHip.x
            centerY = singleHip.y
        } else if let neckPos = poseViewModel.detectedBodyParts[.neck] {
            centerX = neckPos.x
            centerY = neckPos.y + 0.15
        }
        
        var bodyWidth: Double = 0.3
        if let leftShoulder = poseViewModel.detectedBodyParts[.leftShoulder], let rightShoulder = poseViewModel.detectedBodyParts[.rightShoulder] {
            bodyWidth = abs(leftShoulder.x - rightShoulder.x)
        }
        if let leftHip = poseViewModel.detectedBodyParts[.leftHip], let rightHip = poseViewModel.detectedBodyParts[.rightHip] {
            bodyWidth = max(bodyWidth, abs(leftHip.x - rightHip.x))
        }
        
        return (bodyHeight, CGPoint(x: centerX, y: centerY), bodyWidth, true)
    }
    
    private func getTargetPoseReferences(currentPoseIndex: Int) -> (height: Double, center: CGPoint, width: Double) {
        guard currentPoseIndex < poseData.count else { return (1.0, CGPoint(x: 0.5, y: 0.5), 0.3) }
        let targetPose = poseData[currentPoseIndex]
        
        var targetNeckY: CGFloat = 0.3, targetAnkleY: CGFloat = 0.9, targetCenter = CGPoint(x: 0.5, y: 0.5)
        
        if let neckJoint = targetPose.joints["neck"] { targetNeckY = neckJoint.y }
        if let leftAnkle = targetPose.joints["leftAnkle"] ?? targetPose.joints["rightAnkle"] { targetAnkleY = leftAnkle.y }
        
        let targetHeight = abs(targetAnkleY - targetNeckY)
        
        if let leftHip = targetPose.joints["leftHip"], let rightHip = targetPose.joints["rightHip"] {
            targetCenter.x = (leftHip.x + rightHip.x) / 2
            targetCenter.y = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = targetPose.joints["leftHip"] ?? targetPose.joints["rightHip"] {
            targetCenter.x = singleHip.x
            targetCenter.y = singleHip.y
        }
        
        var targetWidth: Double = 0.3
        if let leftShoulder = targetPose.joints["leftShoulder"], let rightShoulder = targetPose.joints["rightShoulder"] {
            targetWidth = abs(leftShoulder.x - rightShoulder.x)
        }
        if let leftHip = targetPose.joints["leftHip"], let rightHip = targetPose.joints["rightHip"] {
            targetWidth = max(targetWidth, abs(leftHip.x - rightHip.x))
        }
        
        return (targetHeight, targetCenter, targetWidth)
    }
    
    private func transformTargetPoint(_ targetPoint: CGPoint, userDimensions: (height: Double, center: CGPoint, width: Double, valid: Bool), targetReferences: (height: Double, center: CGPoint, width: Double), currentPoseIndex: Int) -> CGPoint {
        guard userDimensions.valid, currentPoseIndex < poseData.count else { return targetPoint }
        
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
    
    private func calculateAngle(joint1: CGPoint?, joint2: CGPoint?, joint3: CGPoint?) -> Double? {
        guard let p1 = joint1, let p2 = joint2, let p3 = joint3 else { return nil }
        
        let v1x = p1.x - p2.x, v1y = p1.y - p2.y
        let v2x = p3.x - p2.x, v2y = p3.y - p2.y
        
        let dotProduct = v1x * v2x + v1y * v2y
        let mag1 = sqrt(v1x * v1x + v1y * v1y)
        let mag2 = sqrt(v2x * v2x + v2y * v2y)
        
        if mag1 > 0.0001 && mag2 > 0.0001 {
            let cosAngle = dotProduct / (mag1 * mag2)
            return Foundation.acos(max(-1, min(1, cosAngle)))
        }
        return nil
    }
    
    private func calculateTargetJointDistance(_ joint1Key: String, _ joint2Key: String, targetPose: PoseData) -> Double? {
        guard let joint1 = targetPose.joints[joint1Key], let joint2 = targetPose.joints[joint2Key] else { return nil }
        return distance(CGPoint(x: joint1.x, y: joint1.y), CGPoint(x: joint2.x, y: joint2.y))
    }
    
    private func areJointsTooClose(_ joint1Key: String, _ joint2Key: String, targetPose: PoseData) -> Bool {
        guard let distance = calculateTargetJointDistance(joint1Key, joint2Key, targetPose: targetPose) else { return false }
        return distance < 0.05
    }

    private func getJointImportance(jointName: HumanBodyPoseObservation.JointName, targetPose: PoseData) -> Double {
        let jointKey = PoseMatcher.jointNameToKey(jointName)
        var importance: Double = 1.0
        
        if jointName == .leftHip || jointName == .rightHip, areJointsTooClose("leftHip", "rightHip", targetPose: targetPose) { importance = 0.5 }
        if jointName == .leftShoulder || jointName == .rightShoulder, areJointsTooClose("leftShoulder", "rightShoulder", targetPose: targetPose) { importance = 0.5 }
        if jointName == .leftWrist || jointName == .rightWrist, areJointsTooClose("leftWrist", "rightWrist", targetPose: targetPose) { importance = 0.5 }
        
        if targetPose.poseId == "a3" && (jointName == .leftHip || jointName == .rightHip) {
            importance = 0.4
        }
        return importance
    }
    
    static func jointNameToKey(_ jointName: HumanBodyPoseObservation.JointName) -> String {
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
} 
