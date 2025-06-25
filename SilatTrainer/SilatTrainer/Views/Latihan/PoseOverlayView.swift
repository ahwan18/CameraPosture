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
    let showFittingBox: Bool
    let fittingBoxRect = CGRect(x: 0.10, y: 0.25, width: 0.8, height: 0.7) // Moved down to y: 0.25
    let isUserPositioned: Bool
    let isPositioningPhase: Bool // Added parameter to check for positioning phase
    
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
    private func calculateBodyDimensions() -> (height: CGFloat, center: CGPoint, width: CGFloat, valid: Bool) {
        // Need at least neck and one ankle for a reasonable height estimate
        guard let neck = bodyParts[.neck],
              let leftAnkle = bodyParts[.leftAnkle] ?? bodyParts[.rightAnkle] else {
            return (1.0, CGPoint(x: 0.5, y: 0.5), 0.3, false)
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
        
        // Calculate body width (measured between shoulders and hips)
        var bodyWidth: CGFloat = 0.3 // Default
        if let leftShoulder = bodyParts[.leftShoulder],
           let rightShoulder = bodyParts[.rightShoulder] {
            let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
            bodyWidth = shoulderWidth
        }
        
        // Also consider hip width
        if let leftHip = bodyParts[.leftHip],
           let rightHip = bodyParts[.rightHip] {
            let hipWidth = abs(leftHip.x - rightHip.x)
            // Use the larger of shoulder or hip width
            bodyWidth = max(bodyWidth, hipWidth)
        }
        
        return (bodyHeight, CGPoint(x: centerX, y: centerY), bodyWidth, true)
    }
    
    // Transform target pose points to match user's body proportions and position
    private func transformTargetPoint(_ targetPoint: CGPoint, userBodyDimensions: (height: CGFloat, center: CGPoint, width: CGFloat, valid: Bool)) -> CGPoint {
        guard userBodyDimensions.valid, let targetPose = targetPose else {
            return targetPoint
        }
        
        // Find reference points in target pose for scaling
        var targetNeckY: CGFloat = 0.3 // Default if not found
        var targetAnkleY: CGFloat = 0.9 // Default if not found
        var targetCenter = CGPoint(x: 0.5, y: 0.5) // Default center
        
        if let neckJoint = targetPose.keyPoints["neck"] {
            targetNeckY = neckJoint.y
        }
        
        if let leftAnkle = targetPose.keyPoints["leftAnkle"] ?? targetPose.keyPoints["rightAnkle"] {
            targetAnkleY = leftAnkle.y
        }
        
        // Calculate target pose height
        let targetHeight = abs(targetAnkleY - targetNeckY)
        
        // Calculate center of target pose
        if let leftHip = targetPose.keyPoints["leftHip"], let rightHip = targetPose.keyPoints["rightHip"] {
            targetCenter.x = (leftHip.x + rightHip.x) / 2
            targetCenter.y = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = targetPose.keyPoints["leftHip"] ?? targetPose.keyPoints["rightHip"] {
            targetCenter.x = singleHip.x
            targetCenter.y = singleHip.y
        }
        
        // Calculate target width
        var targetWidth: CGFloat = 0.3 // Default if not found
        if let leftShoulder = targetPose.keyPoints["leftShoulder"],
            let rightShoulder = targetPose.keyPoints["rightShoulder"] {
            let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
            targetWidth = shoulderWidth
        }
        
        // Also consider hip width for target
        if let leftHip = targetPose.keyPoints["leftHip"],
           let rightHip = targetPose.keyPoints["rightHip"] {
            let hipWidth = abs(leftHip.x - rightHip.x)
            targetWidth = max(targetWidth, hipWidth)
        }
        
        // Scale and shift the target point
        let userHeight = userBodyDimensions.height
        let userCenter = userBodyDimensions.center
        let userWidth = userBodyDimensions.width
        
        // Avoid division by zero
        let verticalScaleFactor = (targetHeight > 0.01) ? userHeight / targetHeight : 1.0
        
        // Calculate horizontal scale factor based on body width proportion
        let widthRatio = (targetWidth > 0.01) ? userWidth / targetWidth : 1.0
        
        // Use a blended scale factor to accommodate different body types
        // This reduces the impact of extreme width differences while preserving overall proportions
        let horizontalScaleFactor = (widthRatio + verticalScaleFactor) / 2.0
        
        // Calculate the adjusted position with separate horizontal and vertical scaling
        let relativeX = targetPoint.x - targetCenter.x
        let relativeY = targetPoint.y - targetCenter.y
        
        let adjustedX = userCenter.x + relativeX * horizontalScaleFactor
        let adjustedY = userCenter.y + relativeY * verticalScaleFactor
        
        // Keep points within screen bounds
        let boundedX = min(max(adjustedX, 0.01), 0.99)
        let boundedY = min(max(adjustedY, 0.01), 0.99)
        
        return CGPoint(x: boundedX, y: boundedY)
    }
    
    // Create target pose body parts dictionary
    private func getTargetBodyParts() -> [HumanBodyPoseObservation.JointName: CGPoint] {
        guard let targetPose = targetPose else { return [:] }
        
        var targetBodyParts: [HumanBodyPoseObservation.JointName: CGPoint] = [:]
        
        for (jointKey, jointCoordinate) in targetPose.keyPoints {
            if let jointName = keyToJointName(jointKey) {
                targetBodyParts[jointName] = jointCoordinate
            }
        }
        
        return targetBodyParts
    }
    
    private func lineColor(for connection: BodyConnection) -> Color {
        // Kita hanya perlu memeriksa kesalahan jika panah pemandu aktif (kondisi umum)
        guard showGuideArrows,
              let targetPose = targetPose,
              let fromPoint = bodyParts[connection.from],
              let toPoint = bodyParts[connection.to]
        else {
            // Jika tidak, warna defaultnya selalu hijau
            return .green
        }

        let userBodyDimensions = calculateBodyDimensions()
        let fromKey = jointNameToKey(connection.from)
        let toKey = jointNameToKey(connection.to)

        // Periksa kesalahan untuk sendi 'from'
        if let targetFromJoint = targetPose.keyPoints[fromKey] {
            let originalTargetFrom = targetFromJoint
            let adjustedTargetFrom = transformTargetPoint(originalTargetFrom, userBodyDimensions: userBodyDimensions)
            let dx = adjustedTargetFrom.x - fromPoint.x
            let dy = adjustedTargetFrom.y - fromPoint.y
            if sqrt(dx * dx + dy * dy) > 0.15 {
                return Color(red: 0.8, green: 0, blue: 0.1) // Jika error, langsung kembalikan merah
            }
        }

        // Periksa kesalahan untuk sendi 'to'
        if let targetToJoint = targetPose.keyPoints[toKey] {
            let originalTargetTo = targetToJoint
            let adjustedTargetTo = transformTargetPoint(originalTargetTo, userBodyDimensions: userBodyDimensions)
            let dx = adjustedTargetTo.x - toPoint.x
            let dy = adjustedTargetTo.y - toPoint.y
            if sqrt(dx * dx + dy * dy) > 0.15 {
                return Color(red: 0.8, green: 0, blue: 0.1) // Jika error, langsung kembalikan merah
            }
        }

        // Jika tidak ada sendi yang error, kembalikan hijau
        return .green
    }
    
    private func jointColor(for jointName: HumanBodyPoseObservation.JointName) -> Color {
        // Sama seperti lineColor, periksa dulu kondisi umumnya
        guard showGuideArrows,
              let targetPose = targetPose,
              let currentPoint = bodyParts[jointName]
        else {
            return .green // Warna default jika tidak dalam mode koreksi
        }

        let userBodyDimensions = calculateBodyDimensions()
        let jointKey = jointNameToKey(jointName)

        if let targetJoint = targetPose.keyPoints[jointKey] {
            let adjustedTarget = transformTargetPoint(targetJoint, userBodyDimensions: userBodyDimensions)
            let dx = adjustedTarget.x - currentPoint.x
            let dy = adjustedTarget.y - currentPoint.y
            
            if sqrt(dx * dx + dy * dy) > 0.15 {
                return Color(red: 0.8, green: 0, blue: 0.1) // Sendi ini salah
            }
        }

        // Jika tidak ada kesalahan, warnanya hijau
        return .green
    }
    
    var body: some View {
        GeometryReader { geometry in
            
            // 2. Membuat lapisan ZStack untuk menggambar sendi dan koneksi
            ZStack {
                
                // Ganti bagian showFittingBox dengan kode ini:

                // Alternatif jika mask tidak bekerja - menggunakan 4 rectangle terpisah:

                if showFittingBox {
                    let boxRect = CGRect(
                        x: fittingBoxRect.origin.x * geometry.size.width,
                        y: fittingBoxRect.origin.y * geometry.size.height,
                        width: fittingBoxRect.width * geometry.size.width,
                        height: fittingBoxRect.height * geometry.size.height
                    )
                    
                    // Create selective blur using 4 separate rectangles
                  
                        let blurEffect = Rectangle()
                            .fill(Color.black.opacity(0.5))
                            .saturation(0)
                            .contrast(1.2)
                            .brightness(-0.1)
                            .ignoresSafeArea()
                        
                        // Top rectangle
                        blurEffect
                            .frame(width: geometry.size.width, height: boxRect.minY)
                            .position(x: geometry.size.width/2, y: boxRect.minY/2)
                        
                        // Bottom rectangle
                        blurEffect
                            .frame(width: geometry.size.width, height: geometry.size.height - boxRect.maxY)
                            .position(x: geometry.size.width/2, y: boxRect.maxY + (geometry.size.height - boxRect.maxY)/2)
                        
                        // Left rectangle
                        blurEffect
                            .frame(width: boxRect.minX, height: boxRect.height)
                            .position(x: boxRect.minX/2, y: boxRect.midY)
                        
                        // Right rectangle
                        blurEffect
                            .frame(width: geometry.size.width - boxRect.maxX, height: boxRect.height)
                            .position(x: boxRect.maxX + (geometry.size.width - boxRect.maxX)/2, y: boxRect.midY)
                    
                    
                    // Green positioning frame with thicker corners
                    ZStack {
                        // Box text inside the frame
                        Text("Sesuaikan Posisi Anda \n Di Dalam Kotak")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                            .multilineTextAlignment(.center)
                            .frame(width: boxRect.width)
                            .position(x: boxRect.midX, y: boxRect.midY)
                        
                        // Dynamic corner color based on user position
                        let cornerColor = isUserPositioned ? Color.green : Color.red
                        
                        // Top-left corner
                        CornerShape(corner: .topLeft)
                            .stroke(cornerColor, lineWidth: 16)
                            .frame(width: boxRect.width * 0.2, height: boxRect.height * 0.2)
                            .position(x: boxRect.minX + boxRect.width * 0.1,
                                     y: boxRect.minY + boxRect.height * 0.1)
                        
                        // Top-right corner
                        CornerShape(corner: .topRight)
                            .stroke(cornerColor, lineWidth: 16)
                            .frame(width: boxRect.width * 0.2, height: boxRect.height * 0.2)
                            .position(x: boxRect.maxX - boxRect.width * 0.1,
                                     y: boxRect.minY + boxRect.height * 0.1)
                        
                        // Bottom-left corner
                        CornerShape(corner: .bottomLeft)
                            .stroke(cornerColor, lineWidth: 16)
                            .frame(width: boxRect.width * 0.2, height: boxRect.height * 0.2)
                            .position(x: boxRect.minX + boxRect.width * 0.1,
                                     y: boxRect.maxY - boxRect.height * 0.1)
                        
                        // Bottom-right corner
                        CornerShape(corner: .bottomRight)
                            .stroke(cornerColor, lineWidth: 16)
                            .frame(width: boxRect.width * 0.2, height: boxRect.height * 0.2)
                            .position(x: boxRect.maxX - boxRect.width * 0.1,
                                     y: boxRect.maxY - boxRect.height * 0.1)
                    }
                }
                
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
                                let adjustedFromPoint = transformTargetPoint(fromPoint, userBodyDimensions: userBodyDimensions)
                                let adjustedToPoint = transformTargetPoint(toPoint, userBodyDimensions: userBodyDimensions)
                                
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
                            .stroke(Color.blue.opacity(0.5), lineWidth: 3) // Garis biru semi-transparan
                        }
                    }
                }
                
                // Draw target pose joints in semi-transparent blue with adaptive scaling
                if let targetPose = targetPose {
                    ForEach(Array(targetPose.keyPoints.keys), id: \.self) { jointKey in
                        if let joint = targetPose.keyPoints[jointKey], let jointName = keyToJointName(jointKey) {
                            // Transform target point to match user's proportions
                            let adjustedPoint = transformTargetPoint(joint, userBodyDimensions: userBodyDimensions)
                            
                            let targetPoint = CGPoint(
                                x: adjustedPoint.x * geometry.size.width,
                                y: adjustedPoint.y * geometry.size.height
                            )
                            
                            Circle()
                                .fill(Color.blue.opacity(0.5))
                                .frame(width: 12, height: 12)
                                .position(targetPoint)
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
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
                        
                        // Panggil helper function untuk mendapatkan warna
                        let color = lineColor(for: connection)
                        
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
                        .stroke(color, lineWidth: 5)
                    }
                }
                
                // Draw guide arrows
                if showGuideArrows, let targetPose = targetPose {
                    ForEach(Array(bodyParts.keys), id: \.self) { jointName in
                        if let currentPoint = bodyParts[jointName] {
                            // Convert jointName to string key
                            let jointKey = jointNameToKey(jointName)
                            
                            if let targetJoint = targetPose.keyPoints[jointKey] {
                                // Apply adaptive scaling to target point (these are normalized coordinates)
                                let adjustedTargetPoint = transformTargetPoint(targetJoint, userBodyDimensions: userBodyDimensions)
                                
                                // --- PERUBAHAN UTAMA DI SINI ---
                                // 1. Hitung jarak dalam dunia normalisasi (0.0 - 1.0)
                                let dx = adjustedTargetPoint.x - currentPoint.x
                                let dy = adjustedTargetPoint.y - currentPoint.y
                                let normalizedDistance = sqrt(dx * dx + dy * dy)
                                
                                // 2. Terapkan threshold 0.15
                                if normalizedDistance > 0.15 {
                                    // 3. Jika kondisi terpenuhi, lanjutkan menggambar panah
                                    
                                    // Convert to screen coordinates
                                    let currentPointInView = CGPoint(
                                        x: currentPoint.x * geometry.size.width,
                                        y: currentPoint.y * geometry.size.height
                                    )
                                    let targetPointInView = CGPoint(
                                        x: adjustedTargetPoint.x * geometry.size.width,
                                        y: adjustedTargetPoint.y * geometry.size.height
                                    )
                                    
                                    let arrowInfo = getArrowInfo(from: currentPointInView, to: targetPointInView)
                                    
                                    Path { path in
                                            // Panjang badan panah
                                            let arrowLength: CGFloat = min(arrowInfo.distance * 0.7, 70)
                                            
                                            // Titik akhir badan panah
                                            let endPoint = CGPoint(
                                                x: currentPointInView.x + cos(arrowInfo.angle) * arrowLength,
                                                y: currentPointInView.y + sin(arrowInfo.angle) * arrowLength
                                            )
                                            
                                            // Gambar badan panah
                                            path.move(to: currentPointInView)
                                            path.addLine(to: endPoint)
                                            
                                            // --- LOGIKA KEPALA PANAH BARU ---
                                            // Mengadopsi gaya dari contoh Anda
                                            let arrowHeadLength: CGFloat = 20
                                            let arrowHeadAngle: CGFloat = .pi / 4 // 45 derajat untuk "V" yang lebar

                                            // Hitung titik untuk sayap kiri kepala panah
                                            let head1 = CGPoint(
                                                x: endPoint.x - arrowHeadLength * cos(arrowInfo.angle - arrowHeadAngle),
                                                y: endPoint.y - arrowHeadLength * sin(arrowInfo.angle - arrowHeadAngle)
                                            )
                                            
                                            // Hitung titik untuk sayap kanan kepala panah
                                            let head2 = CGPoint(
                                                x: endPoint.x - arrowHeadLength * cos(arrowInfo.angle + arrowHeadAngle),
                                                y: endPoint.y - arrowHeadLength * sin(arrowInfo.angle + arrowHeadAngle)
                                            )
                                            
                                            // Gambar kepala panah "V"
                                            path.move(to: head1)
                                            path.addLine(to: endPoint)
                                            path.addLine(to: head2)
                                        }
                                        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .miter))
                                        .shadow(color: .black.opacity(1), radius: 3, y: 2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Maps a normalized joint point to screen coordinates with reference scaling
    private func mapNormalizedJointToScreen(jointPoint: CGPoint, poseReferences: (scale: CGFloat, referenceMid: CGPoint, height: CGFloat), geometry: GeometryProxy) -> CGPoint {
        let normalizedX = jointPoint.x
        let normalizedY = jointPoint.y
        
        let screenX = poseReferences.referenceMid.x + (normalizedX - 0.5) * geometry.size.width * poseReferences.scale
        let screenY = poseReferences.referenceMid.y + (normalizedY - 0.5) * geometry.size.height * poseReferences.scale
        
        return CGPoint(x: screenX, y: screenY)
    }
}

/// A shape that draws just the corner of a rectangle
struct CornerShape: Shape {
    enum Corner {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    let corner: Corner
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: 0, y: rect.height * 0.6))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.6, y: 0))
        case .topRight:
            path.move(to: CGPoint(x: rect.width * 0.4, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.6))
        case .bottomLeft:
            path.move(to: CGPoint(x: 0, y: rect.height * 0.4))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.6, y: rect.height))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.width * 0.4, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.4))
        }
        
        return path
    }
}
