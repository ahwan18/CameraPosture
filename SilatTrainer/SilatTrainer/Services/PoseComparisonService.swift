import Foundation
import CoreGraphics

class PoseComparisonService {
    static let shared = PoseComparisonService()
    
    private init() {}
    
    func comparePoses(detected: DetectedPose, reference: PoseReference) -> PoseComparisonResult {
        var jointErrors: [JointName: JointError] = [:]
        var totalSimilarity: Double = 0
        var validJointCount = 0
        var feedbackMessages: [String] = []
        
        // Prioritas untuk feedback - joint yang paling penting
        let priorityJoints: [JointName] = [.rightElbow, .leftElbow, .rightKnee, .leftKnee, .rightWrist, .leftWrist]
        
        for (jointNameString, referenceJoint) in reference.joints {
            guard let jointName = JointName(rawValue: jointNameString),
                  let detectedPosition = detected.joints[jointName] else { continue }
            
            // Skip ignored joints
            if reference.ignoredJoints.contains(jointNameString) {
                continue
            }
            
            let referencePosition = CGPoint(x: referenceJoint.x, y: referenceJoint.y)
            
            // Calculate distance and direction
            let distance = euclideanDistance(detectedPosition, referencePosition)
            let direction = CGVector(
                dx: referencePosition.x - detectedPosition.x,
                dy: referencePosition.y - detectedPosition.y
            )
            
            let jointError = JointError(
                jointName: jointName,
                currentPosition: detectedPosition,
                targetPosition: referencePosition,
                distance: distance,
                direction: direction
            )
            
            jointErrors[jointName] = jointError
            
            // Calculate similarity for this joint (1 - normalized distance)
            let jointSimilarity = max(0, 1.0 - distance)
            
            // Give more weight to important joints
            let weight = reference.importantJoints.contains(jointNameString) ? 2.0 : 1.0
            totalSimilarity += jointSimilarity * weight
            validJointCount += Int(weight)
            
            // Collect feedback messages for joints with significant errors
            if distance > TrainingConfig.jointDistanceThreshold {
                let message = jointError.correctionMessage
                if !message.isEmpty && (reference.importantJoints.contains(jointNameString) || priorityJoints.contains(jointName)) {
                    feedbackMessages.append(message)
                }
            }
        }
        
        // Calculate overall similarity
        let overallSimilarity = validJointCount > 0 ? totalSimilarity / Double(validJointCount) : 0
        
        // Determine if pose is correct
        let isCorrect = overallSimilarity >= TrainingConfig.similarityThreshold
        
        // Limit feedback messages to top 2-3 most important
        let limitedFeedback = Array(feedbackMessages.prefix(2))
        
        return PoseComparisonResult(
            overallSimilarity: overallSimilarity,
            jointErrors: jointErrors,
            isCorrect: isCorrect,
            feedbackMessages: limitedFeedback
        )
    }
    
    private func euclideanDistance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let dx = Double(p1.x - p2.x)
        let dy = Double(p1.y - p2.y)
        return sqrt(dx * dx + dy * dy)
    }
    
    // Alternative: Cosine similarity untuk membandingkan "shape" pose
    func calculateCosineSimilarity(detected: DetectedPose, reference: PoseReference) -> Double {
        // Convert poses to vectors relative to root/center
        guard let detectedRoot = detected.joints[.root],
              let referenceRootJoint = reference.joints["root"] else { return 0 }
        
        let referenceRoot = CGPoint(x: referenceRootJoint.x, y: referenceRootJoint.y)
        
        var vectorA: [Double] = []
        var vectorB: [Double] = []
        
        for jointName in JointName.allCases {
            guard let detectedJoint = detected.joints[jointName],
                  let refJoint = reference.joints[jointName.rawValue],
                  !reference.ignoredJoints.contains(jointName.rawValue) else { continue }
            
            // Create vectors relative to root
            vectorA.append(Double(detectedJoint.x - detectedRoot.x))
            vectorA.append(Double(detectedJoint.y - detectedRoot.y))
            
            vectorB.append(Double(refJoint.x - referenceRoot.x))
            vectorB.append(Double(refJoint.y - referenceRoot.y))
        }
        
        return cosineSimilarity(vectorA, vectorB)
    }
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count && a.count > 0 else { return 0 }
        
        var dotProduct: Double = 0
        var magnitudeA: Double = 0
        var magnitudeB: Double = 0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            magnitudeA += a[i] * a[i]
            magnitudeB += b[i] * b[i]
        }
        
        let magnitude = sqrt(magnitudeA) * sqrt(magnitudeB)
        return magnitude > 0 ? dotProduct / magnitude : 0
    }
} 