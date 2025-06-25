import Foundation
import CoreGraphics
import Vision

class PoseMatcher: PoseMatcherProtocol {
    private let poseData: [PoseData]
    private let poseViewModel: PoseEstimationViewModel
    private let poseMatchThreshold: Double = 0.10 // Acceptable distance threshold for pose matching
    
    init(poseData: [PoseData], poseViewModel: PoseEstimationViewModel) {
        self.poseData = poseData
        self.poseViewModel = poseViewModel
    }

    /// Checks if the detected pose matches the target pose at the specified index
    /// - Parameter currentPoseIndex: The index of the current target pose to check against
    /// - Returns: Boolean indicating if the poses match within the defined threshold
    func checkPoseMatch(currentPoseIndex: Int) -> Bool {
        guard currentPoseIndex < poseData.count else { return false }
        
        let targetPose = poseData[currentPoseIndex]
        let userBodyDimensions = calculateBodyDimensions()
        let targetReferences = getTargetPoseReferences(currentPoseIndex: currentPoseIndex)
        
        var totalDistance: Double = 0
        var totalWeight: Double = 0
        var validJoints = 0
        var worstJointDistance: Double = 0
        var criticalJointsMismatched: Bool = false
        
        // Compare each detected joint with the corresponding target joint
        for (jointName, detectedPoint) in poseViewModel.detectedBodyParts {
            let jointKey = PoseMatcher.jointNameToKey(jointName)
            let jointImportance = getJointImportance(jointName: jointName, targetPose: targetPose)
            
            // If we have a target point for this joint, calculate the distance
            if let targetJoint = targetPose.keyPoints[jointKey] {
                // Transform target point based on user's dimensions
                let transformedTargetPoint = transformTargetPoint(targetJoint, userDimensions: userBodyDimensions, targetReferences: targetReferences, currentPoseIndex: currentPoseIndex)
                
                let jointDistance = distance(detectedPoint, transformedTargetPoint)
                totalDistance += jointDistance * jointImportance
                totalWeight += jointImportance
                validJoints += 1
                
                // Track the worst joint distance for additional threshold check
                if jointDistance > worstJointDistance {
                    worstJointDistance = jointDistance
                }
                
                // Critical joints with higher precision requirements
                // Special case for A5/A6: increase tolerance for wrists
                if (jointName == .leftWrist || jointName == .rightWrist) {
                    // For A5 (index 4) or A6 (index 5), use a more lenient threshold
                    if currentPoseIndex == 4 || currentPoseIndex == 5 {
                        if jointDistance > (poseMatchThreshold * 2.5) {
                            criticalJointsMismatched = true
                        }
                    } else {
                        // For other poses, use standard threshold
                        if jointDistance > (poseMatchThreshold * 1.5) {
                            criticalJointsMismatched = true
                        }
                    }
                }
            }
        }
        
        // Calculate weighted average distance
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
            
            // Get target joints as CGPoints
            let targetJoint1 = targetPose.keyPoints[joint1Key]
            let targetJoint2 = targetPose.keyPoints[joint2Key]
            let targetJoint3 = targetPose.keyPoints[joint3Key]
            
            if let userAngle = calculateAngle(joint1: userJoint1, joint2: userJoint2, joint3: userJoint3),
               let tj1 = targetJoint1, let tj2 = targetJoint2, let tj3 = targetJoint3,
               let targetAngle = calculateAngle(joint1: tj1, joint2: tj2, joint3: tj3) {
                let angleDiff = abs(userAngle - targetAngle)
                let normalizedDiff = angleDiff / .pi
                totalAngleDifference += normalizedDiff
                validAngles += 1
                
                // Special case for A5 and A6: be more lenient with elbow angles
                if (angleConfig.joint2 == .leftElbow || angleConfig.joint2 == .rightElbow) {
                    if currentPoseIndex == 4 || currentPoseIndex == 5 {
                        // For A5/A6, use a more lenient threshold for elbows
                        if normalizedDiff > 0.4 {
                            criticalJointsMismatched = true
                        }
                    } else {
                        // For other poses, use standard threshold
                        if normalizedDiff > 0.25 {
                            criticalJointsMismatched = true
                        }
                    }
                }
            }
        }
        
        let averageAngleDifference = validAngles > 0 ? totalAngleDifference / Double(validAngles) : 1.0
        
        // Use more lenient thresholds for pose A5 and A6
        if currentPoseIndex == 4 || currentPoseIndex == 5 { // A5 or A6
            return averageDistance < (poseMatchThreshold * 1.5) &&
                   worstJointDistance < (poseMatchThreshold * 3.5) &&
                   !criticalJointsMismatched &&
                   averageAngleDifference < 0.30
        } else {
            // Standard thresholds for other poses
            return averageDistance < poseMatchThreshold &&
                   worstJointDistance < (poseMatchThreshold * 2.5) &&
                   !criticalJointsMismatched &&
                   averageAngleDifference < 0.20
        }
    }
    
    //  - Helper Functions
    
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateBodyDimensions() -> (height: Double, center: CGPoint, width: Double, valid: Bool) {
        guard let neck = poseViewModel.detectedBodyParts[.neck],
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
        
        if let neckJoint = targetPose.keyPoints["neck"] { targetNeckY = neckJoint.y }
        if let leftAnkle = targetPose.keyPoints["leftAnkle"] ?? targetPose.keyPoints["rightAnkle"] { targetAnkleY = leftAnkle.y }
        
        let targetHeight = abs(targetAnkleY - targetNeckY)
        
        if let leftHip = targetPose.keyPoints["leftHip"], let rightHip = targetPose.keyPoints["rightHip"] {
            targetCenter.x = (leftHip.x + rightHip.x) / 2
            targetCenter.y = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = targetPose.keyPoints["leftHip"] ?? targetPose.keyPoints["rightHip"] {
            targetCenter.x = singleHip.x
            targetCenter.y = singleHip.y
        }
        
        var targetWidth: Double = 0.3
        if let leftShoulder = targetPose.keyPoints["leftShoulder"], let rightShoulder = targetPose.keyPoints["rightShoulder"] {
            targetWidth = abs(leftShoulder.x - rightShoulder.x)
        }
        if let leftHip = targetPose.keyPoints["leftHip"], let rightHip = targetPose.keyPoints["rightHip"] {
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
        guard let joint1 = targetPose.keyPoints[joint1Key], let joint2 = targetPose.keyPoints[joint2Key] else { return nil }
        return distance(joint1, joint2)
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
        
        if targetPose.id == "a3" && (jointName == .leftHip || jointName == .rightHip) {
            importance = 0.4
        }
        
        // Special case for A5: reduce importance of troublesome joints
        if targetPose.id == "pose_05E530CF" { // A5's ID based on poseData.json
            if jointName == .rightAnkle || jointName == .rightKnee {
                importance = 0.3  // Right leg joints are especially hard in A5
            }
            else if jointName == .leftWrist || jointName == .rightWrist || jointName == .leftElbow || jointName == .rightElbow {
                importance = 0.5  // Make arm positions less critical
            }
        }
        
        // Special case for A6: reduce importance of troublesome joints
        if targetPose.id == "pose_A92E58C7" { // A6's ID based on poseData.json
            if jointName == .rightWrist || jointName == .rightElbow {
                importance = 0.3  // Right arm joints are especially hard in A6
            }
            else if jointName == .leftWrist || jointName == .leftElbow || jointName == .leftAnkle || jointName == .rightAnkle {
                importance = 0.5  // Make these positions less critical
            }
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
