import SwiftUI
import AVFoundation
import Vision
import Combine

// SwiftUI wrapper for camera preview
public struct CameraPreview: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    public func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Add pose overlay view
        let poseOverlayView = PoseOverlayView()
        poseOverlayView.frame = view.frame
        poseOverlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        poseOverlayView.viewModel = viewModel
        view.addSubview(poseOverlayView)
        
        // Observe pose updates
        viewModel.$currentPoseObservation
            .receive(on: DispatchQueue.main)
            .sink { observation in
                poseOverlayView.poseObservation = observation
            }
            .store(in: &context.coordinator.cancellables)
        
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var cancellables = Set<AnyCancellable>()
    }
}

// Custom UIView for drawing pose skeleton
class PoseOverlayView: UIView {
    // Properties
    var poseObservation: VNHumanBodyPoseObservation? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    weak var viewModel: CameraViewModel?
    
    // Skeleton connections
    let skeletonConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.rightShoulder, .rightElbow),
        (.leftElbow, .leftWrist),
        (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip),
        (.root, .rightHip),
        (.leftHip, .leftKnee),
        (.rightHip, .rightKnee),
        (.leftKnee, .leftAnkle),
        (.rightKnee, .rightAnkle)
    ]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.isOpaque = false
        self.backgroundColor = .clear
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(rect)
        
        // Draw user pose if available
        if let observation = poseObservation, let viewModel = viewModel {
            // Draw skeleton
            drawSkeleton(context: context, observation: observation, viewModel: viewModel)
            
            // If in pose matching mode, draw match indicators
            if viewModel.isInPoseMatchingMode, let referencePose = viewModel.referenceBodyPoseObservation {
                drawMatchIndicators(context: context, userPose: observation, referencePose: referencePose, viewModel: viewModel)
            }
        }
    }
    
    private func drawSkeleton(context: CGContext, observation: VNHumanBodyPoseObservation, viewModel: CameraViewModel) {
        // Set line style
        context.setStrokeColor(UIColor.green.cgColor)
        context.setLineWidth(3.0)
        
        // Draw connections
        for (startJointName, endJointName) in skeletonConnections {
            guard let startJoint = try? observation.recognizedPoint(startJointName),
                  let endJoint = try? observation.recognizedPoint(endJointName),
                  startJoint.confidence > 0.3, endJoint.confidence > 0.3 else {
                continue
            }
            
            // Convert normalized coordinates to view coordinates
            let startPoint = CGPoint(x: startJoint.location.x * bounds.width, 
                                   y: (1 - startJoint.location.y) * bounds.height)
            let endPoint = CGPoint(x: endJoint.location.x * bounds.width, 
                                 y: (1 - endJoint.location.y) * bounds.height)
            
            // Draw line
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }
        
        // Draw joint points
        context.setFillColor(UIColor.yellow.cgColor)
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .neck,
            .leftShoulder,
            .rightShoulder,
            .leftElbow,
            .rightElbow,
            .leftWrist,
            .rightWrist,
            .root,
            .leftHip,
            .rightHip,
            .leftKnee,
            .rightKnee,
            .leftAnkle,
            .rightAnkle
        ]
        
        for jointName in jointNames {
            guard let joint = try? observation.recognizedPoint(jointName),
                  joint.confidence > 0.5 else {
                continue
            }
            
            // Convert to view coordinates
            let point = CGPoint(x: joint.location.x * bounds.width,
                               y: (1 - joint.location.y) * bounds.height)
            
            // Draw circle
            let circleRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            context.fillEllipse(in: circleRect)
        }
    }
    
    private func drawMatchIndicators(context: CGContext, userPose: VNHumanBodyPoseObservation, referencePose: VNHumanBodyPoseObservation, viewModel: CameraViewModel) {
        // Draw matching status for joints
        for (jointName, isMatching) in viewModel.jointMatches {
            guard let userJoint = try? userPose.recognizedPoint(jointName),
                  let referenceJoint = try? referencePose.recognizedPoint(jointName),
                  userJoint.confidence > 0.5,
                  referenceJoint.confidence > 0.5 else {
                continue
            }
            
            // Convert to view coordinates
            let userPoint = CGPoint(x: userJoint.location.x * bounds.width,
                                  y: (1 - userJoint.location.y) * bounds.height)
            let referencePoint = CGPoint(x: referenceJoint.location.x * bounds.width,
                                       y: (1 - referenceJoint.location.y) * bounds.height)
            
            if !isMatching {
                // Draw arrow from user joint to reference joint
                drawArrow(context: context, from: userPoint, to: referencePoint)
            }
            
            // Draw indicator based on matching status
            let color = isMatching ? UIColor.green : UIColor.red
            context.setFillColor(color.cgColor)
            
            let circleRect = CGRect(x: userPoint.x - 7, y: userPoint.y - 7, width: 14, height: 14)
            context.fillEllipse(in: circleRect)
            
            // Draw white inner circle for contrast
            context.setFillColor(UIColor.white.cgColor)
            let innerRect = CGRect(x: userPoint.x - 3, y: userPoint.y - 3, width: 6, height: 6)
            context.fillEllipse(in: innerRect)
        }
    }
    
    private func drawArrow(context: CGContext, from startPoint: CGPoint, to endPoint: CGPoint) {
        // Calculate arrow properties
        let arrowLength: CGFloat = 20.0
        let arrowAngle: CGFloat = CGFloat.pi / 6  // 30 degrees
        
        // Calculate direction vector
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // If points are too close, don't draw arrow
        if distance < 10 { return }
        
        // Calculate unit vector
        let unitX = dx / distance
        let unitY = dy / distance
        
        // Calculate arrow head points
        let arrowPoint1X = endPoint.x - arrowLength * (cos(arrowAngle) * unitX + sin(arrowAngle) * unitY)
        let arrowPoint1Y = endPoint.y - arrowLength * (cos(arrowAngle) * unitY - sin(arrowAngle) * unitX)
        let arrowPoint2X = endPoint.x - arrowLength * (cos(arrowAngle) * unitX - sin(arrowAngle) * unitY)
        let arrowPoint2Y = endPoint.y - arrowLength * (cos(arrowAngle) * unitY + sin(arrowAngle) * unitX)
        
        // Set arrow style
        context.setStrokeColor(UIColor.yellow.cgColor)
        context.setLineWidth(2.0)
        
        // Draw arrow shaft
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        
        // Draw arrow head
        context.move(to: endPoint)
        context.addLine(to: CGPoint(x: arrowPoint1X, y: arrowPoint1Y))
        context.move(to: endPoint)
        context.addLine(to: CGPoint(x: arrowPoint2X, y: arrowPoint2Y))
        
        // Stroke the arrow
        context.strokePath()
    }
} 