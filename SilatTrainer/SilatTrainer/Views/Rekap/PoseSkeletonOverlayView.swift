import SwiftUI

/// View untuk menampilkan overlay skeleton dari pose pada gambar user
struct PoseSkeletonOverlayView: View {
    let jointPositions: [String: CGPoint] // User joint positions
    let idealJointPositions: [String: CGPoint]? // Ideal/reference joint positions (optional)
    let threshold: CGFloat = 0.15 // Toleransi error joint
    let lineWidth: CGFloat = 2.0
    let jointRadius: CGFloat = 4.0
    
    // Definisi koneksi antar joint
    private let connections: [(from: String, to: String)] = [
        // Head and torso connections
        ("nose", "neck"),
        ("neck", "rightShoulder"),
        ("neck", "leftShoulder"),
        ("rightShoulder", "rightHip"),
        ("leftShoulder", "leftHip"),
        ("rightHip", "leftHip"),
        
        // Arm connections
        ("rightShoulder", "rightElbow"),
        ("rightElbow", "rightWrist"),
        ("leftShoulder", "leftElbow"),
        ("leftElbow", "leftWrist"),
        
        // Leg connections
        ("rightHip", "rightKnee"),
        ("rightKnee", "rightAnkle"),
        ("leftHip", "leftKnee"),
        ("leftKnee", "leftAnkle")
    ]
    
    // Helper: apakah joint user benar (dalam threshold ke ideal)
    private func isJointCorrect(_ key: String) -> Bool {
        guard let ideal = idealJointPositions?[key], let user = jointPositions[key] else { return false }
        let dx = ideal.x - user.x
        let dy = ideal.y - user.y
        return sqrt(dx*dx + dy*dy) <= threshold
    }
    // Helper: apakah connection benar (kedua joint benar)
    private func isConnectionCorrect(_ from: String, _ to: String) -> Bool {
        isJointCorrect(from) && isJointCorrect(to)
    }
    // Warna joint
    private func jointColor(_ key: String) -> Color {
        guard idealJointPositions != nil else { return .blue }
        return isJointCorrect(key) ? .green : .red
    }
    // Warna garis
    private func lineColor(_ from: String, _ to: String) -> Color {
        guard idealJointPositions != nil else { return .blue }
        return isConnectionCorrect(from, to) ? .green : .red
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Gambar garis antar joint
                ForEach(connections, id: \.from) { connection in
                    if let fromPoint = jointPositions[connection.from],
                       let toPoint = jointPositions[connection.to] {
                        
                        // Skala dan posisi berdasarkan ukuran view
                        let scaledFromPoint = CGPoint(
                            x: fromPoint.x * geometry.size.width,
                            y: fromPoint.y * geometry.size.height
                        )
                        
                        let scaledToPoint = CGPoint(
                            x: toPoint.x * geometry.size.width,
                            y: toPoint.y * geometry.size.height
                        )
                        
                        Path { path in
                            path.move(to: scaledFromPoint)
                            path.addLine(to: scaledToPoint)
                        }
                        .stroke(lineColor(connection.from, connection.to), lineWidth: lineWidth)
                    }
                }
                
                // Gambar titik joint
                ForEach(Array(jointPositions.keys), id: \.self) { key in
                    if let point = jointPositions[key] {
                        let scaledPoint = CGPoint(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        )
                        
                        Circle()
                            .fill(jointColor(key))
                            .frame(width: jointRadius * 2, height: jointRadius * 2)
                            .position(scaledPoint)
                    }
                }
            }
        }
    }
} 