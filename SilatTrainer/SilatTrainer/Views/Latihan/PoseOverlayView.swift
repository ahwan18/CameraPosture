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
                
                // Draw target pose connections (blue lines)
                if let targetPose = targetPose {
                    let targetBodyParts = getTargetBodyParts()
                    
                    ForEach(connections) { connection in
                        if let fromPoint = targetBodyParts[connection.from],
                           let toPoint = targetBodyParts[connection.to] {
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
                            .stroke(Color.blue.opacity(0.7), lineWidth: 3) // Garis biru semi-transparan
                        }
                    }
                }
                
                // Draw target pose joints in semi-transparent blue
                if let targetPose = targetPose {
                    ForEach(Array(targetPose.joints.keys), id: \.self) { jointKey in
                        if let joint = targetPose.joints[jointKey] {
                            let targetPoint = CGPoint(
                                x: joint.x * geometry.size.width,
                                y: joint.y * geometry.size.height
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
                                let currentPointInView = CGPoint(
                                    x: currentPoint.x * geometry.size.width,
                                    y: currentPoint.y * geometry.size.height
                                )
                                let targetPointInView = CGPoint(
                                    x: targetJoint.x * geometry.size.width,
                                    y: targetJoint.y * geometry.size.height
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
