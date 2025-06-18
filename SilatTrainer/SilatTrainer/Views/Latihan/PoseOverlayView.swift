//
//  PoseOverlayView.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 15/06/25.
//

import SwiftUI
import Vision

// Tampilan untuk menampilkan overlay pose tubuh manusia pada layar
// overlay berupa garis dan titik-titik sendi
struct PoseOverlayView: View {

    // Menyimpan koordinat titik-titik sendi tubuh dan koneksi antar sendi
    // bodyParts: Kamus yang memetakan nama sendi ke koordinat titiknya
    // connections: Daftar koneksi antar sendi untuk menggambar garis tubuh
    let bodyParts: [HumanBodyPoseObservation.JointName: CGPoint]
    let connections: [BodyConnection]
    let targetPose: PoseData?
    let showGuideArrows: Bool
    
    // Convert joint key to HumanBodyPoseObservation.JointName
    private func keyToJointName(_ key: String) -> HumanBodyPoseObservation.JointName? {
        switch key {
        case "nose": return .nose
        case "neck": return .neck
        case "leftShoulder": return .leftShoulder
        case "rightShoulder": return .rightShoulder
        case "leftElbow": return .leftElbow
        case "rightElbow": return .rightElbow
        case "leftWrist": return .leftWrist
        case "rightWrist": return .rightWrist
        case "leftHip": return .leftHip
        case "rightHip": return .rightHip
        case "leftKnee": return .leftKnee
        case "rightKnee": return .rightKnee
        case "leftAnkle": return .leftAnkle
        case "rightAnkle": return .rightAnkle
        default: return nil
        }
    }
    
    // Convert HumanBodyPoseObservation.JointName to joint key
    private func jointNameToKey(_ jointName: HumanBodyPoseObservation.JointName) -> String {
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
    
    // Calculate arrow direction and distance
    private func getArrowInfo(from: CGPoint, to: CGPoint) -> (angle: Double, distance: Double) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let angle = atan2(dy, dx)
        let distance = sqrt(dx * dx + dy * dy)
        return (angle, distance)
    }
    
    // Calculate relative body height and position from current pose detection
    private func calculateBodyDimensions() -> (height: CGFloat, center: CGPoint, valid: Bool) {
        // Need at least neck and one ankle for a reasonable height estimate
        guard let neck = bodyParts[.neck],
              let leftAnkle = bodyParts[.leftAnkle] ?? bodyParts[.rightAnkle] else {
            return (1.0, CGPoint(x: 0.5, y: 0.5), false)
        }
        
        // Calculate body height based on detected joints
        let bodyHeight = abs(neck.y - leftAnkle.y)
        
        // Find the center point of the body
        // Start with the hip region as center reference
        var centerX: CGFloat = 0.5
        var centerY: CGFloat = 0.5
        
        if let leftHip = bodyParts[.leftHip], let rightHip = bodyParts[.rightHip] {
            // If both hips are visible, use their average
            centerX = (leftHip.x + rightHip.x) / 2
            centerY = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = bodyParts[.leftHip] ?? bodyParts[.rightHip] {
            // If only one hip is visible
            centerX = singleHip.x
            centerY = singleHip.y
        } else if let neckPos = bodyParts[.neck] {
            // Fall back to neck position adjusted downward
            centerX = neckPos.x
            centerY = neckPos.y + 0.15 // Approximate hip position from neck
        }
        
        return (bodyHeight, CGPoint(x: centerX, y: centerY), true)
    }
    
    // Transform target pose points to match user's body proportions and position
    private func transformTargetPoint(_ targetPoint: CGPoint, userBodyDimensions: (height: CGFloat, center: CGPoint, valid: Bool)) -> CGPoint {
        guard userBodyDimensions.valid, let targetPose = targetPose else {
            return targetPoint
        }
        
        // Find reference points in target pose for scaling
        var targetNeckY: CGFloat = 0.3 // Default if not found
        var targetAnkleY: CGFloat = 0.9 // Default if not found
        var targetCenter = CGPoint(x: 0.5, y: 0.5) // Default center
        
        if let neckJoint = targetPose.joints["neck"] {
            targetNeckY = neckJoint.y
        }
        
        if let leftAnkle = targetPose.joints["leftAnkle"] ?? targetPose.joints["rightAnkle"] {
            targetAnkleY = leftAnkle.y
        }
        
        // Calculate target pose height
        let targetHeight = abs(targetAnkleY - targetNeckY)
        
        // Calculate center of target pose
        if let leftHip = targetPose.joints["leftHip"], let rightHip = targetPose.joints["rightHip"] {
            targetCenter.x = (leftHip.x + rightHip.x) / 2
            targetCenter.y = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = targetPose.joints["leftHip"] ?? targetPose.joints["rightHip"] {
            targetCenter.x = singleHip.x
            targetCenter.y = singleHip.y
        }
        
        // Scale and shift the target point
        let userHeight = userBodyDimensions.height
        let userCenter = userBodyDimensions.center
        
        // Avoid division by zero
        let scaleFactor = (targetHeight > 0.01) ? userHeight / targetHeight : 1.0
        
        // Calculate the adjusted position
        let relativeX = targetPoint.x - targetCenter.x
        let relativeY = targetPoint.y - targetCenter.y
        
        let adjustedX = userCenter.x + relativeX * scaleFactor
        let adjustedY = userCenter.y + relativeY * scaleFactor
        
        // Keep points within screen bounds
        let boundedX = min(max(adjustedX, 0.01), 0.99)
        let boundedY = min(max(adjustedY, 0.01), 0.99)
        
        return CGPoint(x: boundedX, y: boundedY)
    }
    
    // Create target pose body parts dictionary
    private func getTargetBodyParts() -> [HumanBodyPoseObservation.JointName: CGPoint] {
        guard let targetPose = targetPose else { return [:] }
        
        var targetBodyParts: [HumanBodyPoseObservation.JointName: CGPoint] = [:]
        
        for (jointKey, jointCoordinate) in targetPose.joints {
            if let jointName = keyToJointName(jointKey) {
                targetBodyParts[jointName] = CGPoint(x: jointCoordinate.x, y: jointCoordinate.y)
            }
        }
        
        return targetBodyParts
    }
    
    var body: some View {
        GeometryReader { geometry in
        
            // 2. Membuat lapisan ZStack untuk menggambar sendi dan koneksi
            ZStack {
                // Calculate user body dimensions for adaptive transformations
                let userBodyDimensions = calculateBodyDimensions()
                
                // Draw target pose connections (blue lines) with adaptive scaling
                if let targetPose = targetPose {
                    let targetBodyParts = getTargetBodyParts()
                    
                    ForEach(connections) { connection in
                        if let fromPoint = targetBodyParts[connection.from],
                           let toPoint = targetBodyParts[connection.to] {
                            Path { path in
                                // Transform target points to match user's proportions
                                let adjustedFromPoint = userBodyDimensions.valid ? 
                                    transformTargetPoint(fromPoint, userBodyDimensions: userBodyDimensions) : fromPoint
                                let adjustedToPoint = userBodyDimensions.valid ? 
                                    transformTargetPoint(toPoint, userBodyDimensions: userBodyDimensions) : toPoint
                                
                                // Mengonversi koordinat titik ke koordinat tampilan
                                let fromPointInView = CGPoint(
                                    x: adjustedFromPoint.x * geometry.size.width,
                                    y: adjustedFromPoint.y * geometry.size.height
                                )
                                let toPointInView = CGPoint(
                                    x: adjustedToPoint.x * geometry.size.width,
                                    y: adjustedToPoint.y * geometry.size.height
                                )
                                
                                // Membuat garis dari satu sendi ke sendi lainnya
                                path.move(to: fromPointInView)
                                path.addLine(to: toPointInView)
                            }
                            .stroke(Color.blue.opacity(0.7), lineWidth: 3) // Garis biru semi-transparan
                        }
                    }
                }
                
                // Draw target pose joints in semi-transparent blue with adaptive scaling
                if let targetPose = targetPose {
                    ForEach(Array(targetPose.joints.keys), id: \.self) { jointKey in
                        if let joint = targetPose.joints[jointKey], let jointName = keyToJointName(jointKey) {
                            // Transform target point to match user's proportions
                            let originalPoint = CGPoint(x: joint.x, y: joint.y)
                            let adjustedPoint = userBodyDimensions.valid ? 
                                transformTargetPoint(originalPoint, userBodyDimensions: userBodyDimensions) : originalPoint
                            
                            let targetPoint = CGPoint(
                                x: adjustedPoint.x * geometry.size.width,
                                y: adjustedPoint.y * geometry.size.height
                            )
                            
                            Circle()
                                .fill(Color.blue.opacity(0.6))
                                .frame(width: 12, height: 12)
                                .position(targetPoint)
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                        .frame(width: 16, height: 16)
                                        .position(targetPoint)
                                )
                        }
                    }
                }
                
                // Menggambar garis koneksi antar sendi (user's current pose)
                ForEach(connections) { connection in
                    if let fromPoint = bodyParts[connection.from],
                       let toPoint = bodyParts[connection.to] {
                        Path { path in
                            // Mengonversi koordinat titik ke koordinat tampilan
                            let fromPointInView = CGPoint(
                                x: fromPoint.x * geometry.size.width,
                                y: fromPoint.y * geometry.size.height
                            )
                            let toPointInView = CGPoint(
                                x: toPoint.x * geometry.size.width,
                                y: toPoint.y * geometry.size.height
                            )
                            
                            // Membuat garis dari satu sendi ke sendi lainnya
                            path.move(to: fromPointInView)
                            path.addLine(to: toPointInView)
                        }
                        .stroke(Color.green, lineWidth: 3) // Garis berwarna hijau dengan ketebalan 3
                    }
                }
                
                // 3. Menggambar titik-titik sendi pada tampilan (user's current pose)
                ForEach(Array(bodyParts.keys), id: \.self) { jointName in
                    if let point = bodyParts[jointName] {
                        // Mengonversi koordinat titik sendi ke koordinat tampilan
                        let pointInView = CGPoint(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        )
                        
                        // Membuat lingkaran putih untuk setiap titik sendi
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                            .position(pointInView)
                            .overlay(
                                ZStack{
                                    // Menambahkan outline putih di sekitar lingkaran
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                        .frame(width: 12, height: 12)
                                }
                            )
                    }
                }
                
                // Draw guide arrows
                if showGuideArrows, let targetPose = targetPose {
                    ForEach(Array(bodyParts.keys), id: \.self) { jointName in
                        if let currentPoint = bodyParts[jointName] {
                            // Convert jointName to string key
                            let jointKey = jointNameToKey(jointName)
                            
                            if let targetJoint = targetPose.joints[jointKey] {
                                // Convert to screen coordinates
                                let currentPointInView = CGPoint(
                                    x: currentPoint.x * geometry.size.width,
                                    y: currentPoint.y * geometry.size.height
                                )
                                
                                // Apply adaptive scaling to target point
                                let originalTargetPoint = CGPoint(x: targetJoint.x, y: targetJoint.y)
                                let adjustedTargetPoint = userBodyDimensions.valid ? 
                                    transformTargetPoint(originalTargetPoint, userBodyDimensions: userBodyDimensions) : originalTargetPoint
                                let targetPointInView = CGPoint(
                                    x: adjustedTargetPoint.x * geometry.size.width,
                                    y: adjustedTargetPoint.y * geometry.size.height
                                )
                                
                                let arrowInfo = getArrowInfo(from: currentPointInView, to: targetPointInView)
                                
                                // Only show arrow if distance is significant (more than 20 pixels)
                                if arrowInfo.distance > 20 {
                                    // Draw arrow
                                    Path { path in
                                        let arrowLength: CGFloat = min(arrowInfo.distance * 0.7, 50)
                                        let arrowHeadSize: CGFloat = 8
                                        
                                        // Arrow body
                                        let endX = currentPointInView.x + cos(arrowInfo.angle) * arrowLength
                                        let endY = currentPointInView.y + sin(arrowInfo.angle) * arrowLength
                                        let endPoint = CGPoint(x: endX, y: endY)
                                        
                                        path.move(to: currentPointInView)
                                        path.addLine(to: endPoint)
                                        
                                        // Arrow head
                                        let angle1 = arrowInfo.angle + .pi * 0.8
                                        let angle2 = arrowInfo.angle - .pi * 0.8
                                        
                                        let head1 = CGPoint(
                                            x: endX + cos(angle1) * arrowHeadSize,
                                            y: endY + sin(angle1) * arrowHeadSize
                                        )
                                        let head2 = CGPoint(
                                            x: endX + cos(angle2) * arrowHeadSize,
                                            y: endY + sin(angle2) * arrowHeadSize
                                        )
                                        
                                        path.move(to: endPoint)
                                        path.addLine(to: head1)
                                        path.move(to: endPoint)
                                        path.addLine(to: head2)
                                    }
                                    .stroke(Color.red, lineWidth: 3)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
