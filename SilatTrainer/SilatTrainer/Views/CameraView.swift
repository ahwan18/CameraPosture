import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // No updates needed
    }
}

class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// Camera preview with pose overlay
struct CameraPreviewView: View {
    @ObservedObject var cameraService: CameraService
    let detectedPose: DetectedPose?
    let comparisonResult: PoseComparisonResult?
    let showSkeleton: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                if cameraService.isSessionRunning {
                    CameraView(session: cameraService.session)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                }
                
                // Pose overlay
                if showSkeleton, let pose = detectedPose {
                    PoseOverlayView(
                        detectedPose: pose,
                        comparisonResult: comparisonResult,
                        frameSize: geometry.size
                    )
                }
            }
        }
    }
}

// Overlay for showing detected pose and corrections
struct PoseOverlayView: View {
    let detectedPose: DetectedPose
    let comparisonResult: PoseComparisonResult?
    let frameSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Draw skeleton connections
            drawSkeleton(context: context, size: size)
            
            // Draw joints
            for (jointName, position) in detectedPose.joints {
                let point = denormalizePoint(position, in: size)
                let color = colorForJoint(jointName)
                
                // Draw joint circle
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - 8,
                        y: point.y - 8,
                        width: 16,
                        height: 16
                    )),
                    with: .color(color)
                )
                
                // Draw correction arrow if needed
                if let error = comparisonResult?.jointErrors[jointName],
                   error.distance > TrainingConfig.jointDistanceThreshold {
                    drawCorrectionArrow(
                        context: context,
                        from: point,
                        direction: error.direction,
                        in: size
                    )
                }
            }
        }
    }
    
    private func drawSkeleton(context: GraphicsContext, size: CGSize) {
        let connections: [(JointName, JointName)] = [
            // Head
            (.nose, .neck),
            (.leftEye, .nose), (.rightEye, .nose),
            (.leftEar, .leftEye), (.rightEar, .rightEye),
            
            // Arms
            (.neck, .leftShoulder), (.neck, .rightShoulder),
            (.leftShoulder, .leftElbow), (.rightShoulder, .rightElbow),
            (.leftElbow, .leftWrist), (.rightElbow, .rightWrist),
            
            // Body
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .root), (.rightHip, .root),
            
            // Legs
            (.leftHip, .leftKnee), (.rightHip, .rightKnee),
            (.leftKnee, .leftAnkle), (.rightKnee, .rightAnkle)
        ]
        
        for (joint1, joint2) in connections {
            guard let pos1 = detectedPose.joints[joint1],
                  let pos2 = detectedPose.joints[joint2] else { continue }
            
            let point1 = denormalizePoint(pos1, in: size)
            let point2 = denormalizePoint(pos2, in: size)
            
            var path = Path()
            path.move(to: point1)
            path.addLine(to: point2)
            
            context.stroke(path, with: .color(.white.opacity(0.7)), lineWidth: 2)
        }
    }
    
    private func drawCorrectionArrow(context: GraphicsContext, from point: CGPoint, direction: CGVector, in size: CGSize) {
        let arrowLength: CGFloat = 40
        let arrowEnd = CGPoint(
            x: point.x + direction.dx * arrowLength,
            y: point.y + direction.dy * arrowLength
        )
        
        var path = Path()
        path.move(to: point)
        path.addLine(to: arrowEnd)
        
        // Add arrowhead
        let angle = atan2(direction.dy, direction.dx)
        let arrowAngle: CGFloat = .pi / 6
        let arrowHeadLength: CGFloat = 12
        
        let leftPoint = CGPoint(
            x: arrowEnd.x - arrowHeadLength * cos(angle - arrowAngle),
            y: arrowEnd.y - arrowHeadLength * sin(angle - arrowAngle)
        )
        
        let rightPoint = CGPoint(
            x: arrowEnd.x - arrowHeadLength * cos(angle + arrowAngle),
            y: arrowEnd.y - arrowHeadLength * sin(angle + arrowAngle)
        )
        
        path.move(to: leftPoint)
        path.addLine(to: arrowEnd)
        path.addLine(to: rightPoint)
        
        context.stroke(path, with: .color(.yellow), lineWidth: 3)
    }
    
    private func denormalizePoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: point.y * size.height
        )
    }
    
    private func colorForJoint(_ joint: JointName) -> Color {
        guard let result = comparisonResult,
              let error = result.jointErrors[joint] else {
            return .green
        }
        
        if error.distance > TrainingConfig.jointDistanceThreshold {
            return .red
        } else if error.distance > TrainingConfig.jointDistanceThreshold * 0.5 {
            return .orange
        } else {
            return .green
        }
    }
} 