import SwiftUI

/// View untuk menampilkan overlay skeleton dari pose pada gambar user
struct PoseSkeletonOverlayView: View {
    let jointPositions: [String: CGPoint]
    let lineColor: Color = .blue
    let jointColor: Color = .red
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
                        .stroke(lineColor, lineWidth: lineWidth)
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
                            .fill(jointColor)
                            .frame(width: jointRadius * 2, height: jointRadius * 2)
                            .position(scaledPoint)
                    }
                }
            }
        }
    }
} 