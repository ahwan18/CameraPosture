import SwiftUI
import Vision

struct PoseOverlayView: View {
    
    let bodyParts: [HumanBodyPoseObservation.JointName: CGPoint]
    let connections: [BodyConnection]
    let feedbacks: [PoseComparison.Feedback]
    let holdProgress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. CONNECTIONS (Skeleton lines)
                ForEach(connections) { connection in
                    if let fromPoint = bodyParts[connection.from],
                       let toPoint = bodyParts[connection.to] {
                        Path { path in
                            let fromPointInView = CGPoint(
                                x: fromPoint.x * geometry.size.width,
                                y: fromPoint.y * geometry.size.height
                            )
                            let toPointInView = CGPoint(
                                x: toPoint.x * geometry.size.width,
                                y: toPoint.y * geometry.size.height
                            )
                            
                            path.move(to: fromPointInView)
                            path.addLine(to: toPointInView)
                        }
                        .stroke(Color.green, lineWidth: 3)
                    }
                }
                
                // 2. JOINT POINTS (White circles)
                ForEach(Array(bodyParts.keys), id: \.self) { jointName in
                    if let point = bodyParts[jointName] {
                        let pointInView = CGPoint(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        )
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                            .position(pointInView)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                                    .frame(width: 12, height: 12)
                                    .position(pointInView)
                            )
                    }
                }
                
                // 3. FEEDBACK ARROWS - PERBAIKAN UTAMA
                ForEach(Array(feedbacks.enumerated()), id: \.offset) { index, feedback in
                    if let jointPoint = bodyParts[feedback.joint] {
                        ArrowView(
                            from: CGPoint(
                                x: jointPoint.x * geometry.size.width,
                                y: jointPoint.y * geometry.size.height
                            ),
                            direction: feedback.direction,
                            geometry: geometry
                        )
                    }
                }
                
                // 4. HOLD PROGRESS INDICATOR
                if holdProgress > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack {
                                Text("Hold Progress")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                ProgressView(value: holdProgress)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                    .frame(width: 60, height: 60)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(10)
                            }
                            .padding()
                        }
                    }
                }
                
                // 5. DEBUG INFO (untuk development - bisa dihapus nanti)
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Debug Info:")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("Feedbacks: \(feedbacks.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text("Body Parts: \(bodyParts.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            // Show feedback details
                            ForEach(Array(feedbacks.enumerated()), id: \.offset) { index, feedback in
                                Text("Feedback \(index): \(feedback.joint.rawValue) - \(feedback.direction)")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
}

struct ArrowView: View {
    let from: CGPoint
    let direction: PoseComparison.Direction
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // ARROW PATH
            Path { path in
                let arrowLength: CGFloat = 50 // Diperbesar dari 30
                
                // Calculate end point based on direction
                let endPoint: CGPoint
                switch direction {
                case .up:
                    endPoint = CGPoint(x: from.x, y: from.y - arrowLength)
                case .down:
                    endPoint = CGPoint(x: from.x, y: from.y + arrowLength)
                case .left:
                    endPoint = CGPoint(x: from.x - arrowLength, y: from.y)
                case .right:
                    endPoint = CGPoint(x: from.x + arrowLength, y: from.y)
                case .forward:
                    // For forward, we'll use up-right diagonal
                    endPoint = CGPoint(x: from.x + arrowLength * 0.7, y: from.y - arrowLength * 0.7)
                case .backward:
                    // For backward, we'll use down-left diagonal
                    endPoint = CGPoint(x: from.x - arrowLength * 0.7, y: from.y + arrowLength * 0.7)
                }
                
                // Draw arrow line
                path.move(to: from)
                path.addLine(to: endPoint)
                
                // Draw arrow head
                let arrowHeadLength: CGFloat = 15 // Diperbesar dari 10
                let arrowHeadAngle: CGFloat = .pi / 4 // 45 degrees (lebih lebar)
                
                let dx = endPoint.x - from.x
                let dy = endPoint.y - from.y
                let angle = atan2(dy, dx)
                
                let arrowHead1 = CGPoint(
                    x: endPoint.x - arrowHeadLength * cos(angle + arrowHeadAngle),
                    y: endPoint.y - arrowHeadLength * sin(angle + arrowHeadAngle)
                )
                
                let arrowHead2 = CGPoint(
                    x: endPoint.x - arrowHeadLength * cos(angle - arrowHeadAngle),
                    y: endPoint.y - arrowHeadLength * sin(angle - arrowHeadAngle)
                )
                
                path.move(to: endPoint)
                path.addLine(to: arrowHead1)
                path.move(to: endPoint)
                path.addLine(to: arrowHead2)
            }
            .stroke(Color.red, lineWidth: 4) // Diperbesar dari 2
            .shadow(color: .black, radius: 2) // Tambah shadow untuk visibility
            
            // DIRECTION LABEL (untuk debug)
            Text(directionLabel)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.red.opacity(0.8))
                .cornerRadius(4)
                .position(
                    CGPoint(
                        x: from.x + directionOffset.x,
                        y: from.y + directionOffset.y
                    )
                )
        }
    }
    
    private var directionLabel: String {
        switch direction {
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .forward: return "↗"
        case .backward: return "↙"
        }
    }
    
    private var directionOffset: CGPoint {
        switch direction {
        case .up: return CGPoint(x: 20, y: -30)
        case .down: return CGPoint(x: 20, y: 30)
        case .left: return CGPoint(x: -30, y: -10)
        case .right: return CGPoint(x: 30, y: -10)
        case .forward: return CGPoint(x: 25, y: -25)
        case .backward: return CGPoint(x: -25, y: 25)
        }
    }
}

// EXTENSION untuk debug - bisa ditambahkan di file terpisah
extension PoseComparison.Feedback {
    var debugDescription: String {
        return "\(joint.rawValue): \(message) (\(direction))"
    }
}

// PREVIEW untuk testing
#Preview {
    PoseOverlayView(
        bodyParts: [
            .nose: CGPoint(x: 0.5, y: 0.2),
            .leftShoulder: CGPoint(x: 0.4, y: 0.3),
            .rightShoulder: CGPoint(x: 0.6, y: 0.3)
        ],
        connections: [],
        feedbacks: [
            PoseComparison.Feedback(
                joint: .leftShoulder,
                direction: .up,
                message: "Angkat bahu kiri"
            )
        ],
        holdProgress: 0.5
    )
    .frame(width: 300, height: 400)
    .background(Color.black)
}
