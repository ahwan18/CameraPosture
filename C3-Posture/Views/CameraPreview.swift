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
        
        // Add positioning box overlay view
        let positioningBoxView = PositioningBoxView()
        positioningBoxView.frame = view.frame
        positioningBoxView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        positioningBoxView.viewModel = viewModel
        view.addSubview(positioningBoxView)
        
        // Observe pose updates
        viewModel.$currentPoseObservation
            .receive(on: DispatchQueue.main)
            .sink { observation in
                poseOverlayView.poseObservation = observation
            }
            .store(in: &context.coordinator.cancellables)
        
        // Observe positioning box updates
        viewModel.$showPositioningBox
            .receive(on: DispatchQueue.main)
            .sink { shouldShow in
                positioningBoxView.isHidden = !shouldShow
            }
            .store(in: &context.coordinator.cancellables)
        
        viewModel.$isUserInPositioningBox
            .receive(on: DispatchQueue.main)
            .sink { isInBox in
                positioningBoxView.isUserInBox = isInBox
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

// Custom UIView for positioning box overlay
class PositioningBoxView: UIView {
    weak var viewModel: CameraViewModel?
    var isUserInBox: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
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
        
        // Draw positioning box outline
        drawPositioningBox(context: context, rect: rect)
        
        // Draw instructions
        drawInstructions(context: context, rect: rect)
    }
    
    private func drawPositioningBox(context: CGContext, rect: CGRect) {
        // Calculate optimal box size and position for full body capture (smaller box for 3m distance)
        let boxWidth: CGFloat = rect.width * 0.45
        let boxHeight: CGFloat = rect.height * 0.65
        let boxX = (rect.width - boxWidth) / 2
        let boxY = (rect.height - boxHeight) / 2
        
        let boxRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)
        
        // Set box style based on user position
        let boxColor = isUserInBox ? UIColor.green : UIColor.orange
        context.setStrokeColor(boxColor.cgColor)
        context.setLineWidth(4.0)
        
        // Draw main box
        context.stroke(boxRect)
        
        // Draw corner markers for better visibility
        let cornerLength: CGFloat = 30
        let corners = [
            CGPoint(x: boxRect.minX, y: boxRect.minY), // Top-left
            CGPoint(x: boxRect.maxX, y: boxRect.minY), // Top-right
            CGPoint(x: boxRect.minX, y: boxRect.maxY), // Bottom-left
            CGPoint(x: boxRect.maxX, y: boxRect.maxY)  // Bottom-right
        ]
        
        context.setLineWidth(6.0)
        for corner in corners {
            // Horizontal line
            context.move(to: CGPoint(x: corner.x - (corner.x == boxRect.minX ? 0 : cornerLength), 
                                   y: corner.y))
            context.addLine(to: CGPoint(x: corner.x + (corner.x == boxRect.maxX ? 0 : cornerLength), 
                                      y: corner.y))
            
            // Vertical line
            context.move(to: CGPoint(x: corner.x, 
                                   y: corner.y - (corner.y == boxRect.minY ? 0 : cornerLength)))
            context.addLine(to: CGPoint(x: corner.x, 
                                      y: corner.y + (corner.y == boxRect.maxY ? 0 : cornerLength)))
        }
        context.strokePath()
        
        // Draw center alignment guide
        let centerX = rect.width / 2
        let centerY = rect.height / 2
        let crossSize: CGFloat = 20
        
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        
        // Horizontal line
        context.move(to: CGPoint(x: centerX - crossSize, y: centerY))
        context.addLine(to: CGPoint(x: centerX + crossSize, y: centerY))
        
        // Vertical line
        context.move(to: CGPoint(x: centerX, y: centerY - crossSize))
        context.addLine(to: CGPoint(x: centerX, y: centerY + crossSize))
        
        context.strokePath()
    }
    
    private func drawInstructions(context: CGContext, rect: CGRect) {
        let statusText: String
        let textColor: UIColor
        
        if isUserInBox {
            statusText = "Perfect! Get ready..."
            textColor = .green
                 } else {
             statusText = "Stand within the box\nOptimal distance: 3 meters"
             textColor = .white
         }
        
        // Create attributed string
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0
        ]
        
        let attributedString = NSAttributedString(string: statusText, attributes: attributes)
        
        // Calculate text position
        let textSize = attributedString.boundingRect(
            with: CGSize(width: rect.width - 40, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
        
        let textRect = CGRect(
            x: (rect.width - textSize.width) / 2,
            y: rect.height * 0.15 - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw text background
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        let backgroundRect = textRect.insetBy(dx: -10, dy: -5)
        context.fillEllipse(in: backgroundRect)
        
        // Draw text
        attributedString.draw(in: textRect)
        
        // Draw distance indicator
        if !isUserInBox {
            drawDistanceIndicator(context: context, rect: rect)
        }
    }
    
    private func drawDistanceIndicator(context: CGContext, rect: CGRect) {
        // Draw distance scale at the bottom
        let scaleY = rect.height * 0.9
        let scaleWidth = rect.width * 0.6
        let scaleX = (rect.width - scaleWidth) / 2
        
        // Scale background
        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        let scaleRect = CGRect(x: scaleX - 10, y: scaleY - 20, width: scaleWidth + 20, height: 40)
        context.fill(scaleRect.insetBy(dx: 0, dy: 0))
        
        // Scale line
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.move(to: CGPoint(x: scaleX, y: scaleY))
        context.addLine(to: CGPoint(x: scaleX + scaleWidth, y: scaleY))
        context.strokePath()
        
        // Optimal zone indicator
        let optimalStart = scaleX + scaleWidth * 0.35
        let optimalEnd = scaleX + scaleWidth * 0.65
        
        context.setStrokeColor(UIColor.green.cgColor)
        context.setLineWidth(6.0)
        context.move(to: CGPoint(x: optimalStart, y: scaleY))
        context.addLine(to: CGPoint(x: optimalEnd, y: scaleY))
        context.strokePath()
        
        // Labels
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        
        let tooFarText = NSAttributedString(string: "Too far", attributes: labelAttributes)
        let optimalText = NSAttributedString(string: "Optimal", attributes: labelAttributes)
        let tooCloseText = NSAttributedString(string: "Too close", attributes: labelAttributes)
        
        tooFarText.draw(at: CGPoint(x: scaleX, y: scaleY + 10))
        optimalText.draw(at: CGPoint(x: optimalStart, y: scaleY + 10))
        tooCloseText.draw(at: CGPoint(x: optimalEnd + 10, y: scaleY + 10))
    }
}



