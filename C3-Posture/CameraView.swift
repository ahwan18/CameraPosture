import SwiftUI
import AVFoundation
import Vision
import Combine
import ImageIO // For CGImagePropertyOrientation

class CameraViewModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isPostureGood = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var currentPoseObservation: VNHumanBodyPoseObservation?
    @Published var isPersonDetected = false
    @Published var personBoundingBox: CGRect?
    @Published var isLeftElbowGood: Bool = true
    @Published var isRightElbowGood: Bool = true
    @Published var isSetupMode: Bool = true
    @Published var targetPersonBox: CGRect? = nil
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                      for: .video,
                                                      position: cameraPosition) else { return }
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        guard session.canAddInput(videoDeviceInput) else { return }
        session.addInput(videoDeviceInput)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutput", qos: .userInitiated))
        
        guard session.canAddOutput(videoDataOutput) else { return }
        session.addOutput(videoDataOutput)
        
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated)
        
        session.commitConfiguration()
    }
    
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        setupCamera()
    }
    
    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    private func isInCenterArea(_ boundingBox: CGRect) -> Bool {
        let centerX = boundingBox.midX
        let centerY = boundingBox.midY
        
        // Define center area (adjust these values to change the center area size)
        let centerAreaWidth: CGFloat = 0.4  // 40% of screen width
        let centerAreaHeight: CGFloat = 0.4  // 40% of screen height
        
        let minX = (1.0 - centerAreaWidth) / 2
        let maxX = minX + centerAreaWidth
        let minY = (1.0 - centerAreaHeight) / 2
        let maxY = minY + centerAreaHeight
        
        return centerX >= minX && centerX <= maxX && centerY >= minY && centerY <= maxY
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let orientation: CGImagePropertyOrientation
        if cameraPosition == .front {
            orientation = .leftMirrored
        } else {
            orientation = .right
        }
        let personDetectionRequest = VNDetectHumanRectanglesRequest()
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([personDetectionRequest, poseRequest])
            let personObservations = personDetectionRequest.results as? [VNHumanObservation] ?? []
            let poseObservations = poseRequest.results as? [VNHumanBodyPoseObservation] ?? []
            if personObservations.isEmpty {
                DispatchQueue.main.async {
                    self.isPersonDetected = false
                    self.personBoundingBox = nil
                    self.currentPoseObservation = nil
                    self.isPostureGood = false
                }
                return
            }
            // Helper: get center point of bounding box
            func boxCenter(_ box: CGRect) -> CGPoint {
                CGPoint(x: box.midX, y: box.midY)
            }
            // Helper: get center point of pose (average of left/right shoulder, fallback to neck)
            func poseCenter(_ pose: VNHumanBodyPoseObservation) -> CGPoint? {
                if let left = try? pose.recognizedPoint(.leftShoulder),
                   let right = try? pose.recognizedPoint(.rightShoulder) {
                    return CGPoint(x: (left.location.x + right.location.x)/2, y: (left.location.y + right.location.y)/2)
                } else if let neck = try? pose.recognizedPoint(.neck) {
                    return neck.location
                }
                return nil
            }
            var selectedBox: CGRect? = nil
            var selectedPose: VNHumanBodyPoseObservation? = nil
            if isSetupMode {
                // Setup mode: ambil person dengan confidence tertinggi
                let best = personObservations.max { $0.confidence < $1.confidence }
                selectedBox = best?.boundingBox
                // Cari pose terdekat dengan box
                if let bestBox = selectedBox {
                    selectedPose = poseObservations.min(by: {
                        guard let c0 = poseCenter($0), let c1 = poseCenter($1) else { return false }
                        let d0 = distance(boxCenter(bestBox), c0)
                        let d1 = distance(boxCenter(bestBox), c1)
                        return d0 < d1
                    })
                }
            } else if let targetBox = targetPersonBox {
                // Evaluasi: cari person terdekat dengan target
                let best = personObservations.min(by: { distance(boxCenter($0.boundingBox), boxCenter(targetBox)) < distance(boxCenter($1.boundingBox), boxCenter(targetBox)) })
                selectedBox = best?.boundingBox
                if let bestBox = selectedBox {
                    selectedPose = poseObservations.min(by: {
                        guard let c0 = poseCenter($0), let c1 = poseCenter($1) else { return false }
                        let d0 = distance(boxCenter(bestBox), c0)
                        let d1 = distance(boxCenter(bestBox), c1)
                        return d0 < d1
                    })
                }
            }
            DispatchQueue.main.async {
                self.isPersonDetected = selectedBox != nil
                self.personBoundingBox = selectedBox
                self.currentPoseObservation = selectedPose
                if self.isSetupMode {
                    self.isPostureGood = false
                } else if let pose = selectedPose {
                    self.analyzePosture(pose)
                } else {
                    self.isPostureGood = false
                }
            }
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
    }
    
    private func analyzePosture(_ observation: VNHumanBodyPoseObservation) {
        // Get key points for left and right arm
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let leftElbow = try? observation.recognizedPoint(.leftElbow),
              let leftWrist = try? observation.recognizedPoint(.leftWrist),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              let rightElbow = try? observation.recognizedPoint(.rightElbow),
              let rightWrist = try? observation.recognizedPoint(.rightWrist) else {
            return
        }

        // Calculate angle for left arm (shoulder–elbow–wrist)
        let leftArmAngle = angleBetween(p1: leftShoulder.location, vertex: leftElbow.location, p3: leftWrist.location)
        // Calculate angle for right arm (shoulder–elbow–wrist)
        let rightArmAngle = angleBetween(p1: rightShoulder.location, vertex: rightElbow.location, p3: rightWrist.location)

        let targetArmAngle: CGFloat = 170 // <--- Ubah nilai ini untuk target derajat postur tangan ke atas (angkat tangan)
        let tolerance: CGFloat = 10      // <--- Ubah toleransi derajat jika perlu (untuk range 160–180)

        let leftIsGood = abs(leftArmAngle - targetArmAngle) < tolerance
        let rightIsGood = abs(rightArmAngle - targetArmAngle) < tolerance

        DispatchQueue.main.async {
            self.isPostureGood = leftIsGood && rightIsGood
            self.isLeftElbowGood = leftIsGood
            self.isRightElbowGood = rightIsGood
        }
    }

    // Helper function to calculate angle in degrees
    private func angleBetween(p1: CGPoint, vertex: CGPoint, p3: CGPoint) -> CGFloat {
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p3.x - vertex.x, dy: p3.y - vertex.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        let angle = acos(dot / (mag1 * mag2))
        return angle * 180 / .pi
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx*dx + dy*dy)
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
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
        
        // Set up observation for pose updates
        viewModel.$currentPoseObservation
            .receive(on: DispatchQueue.main)
            .sink { observation in
                poseOverlayView.poseObservation = observation
            }
            .store(in: &context.coordinator.cancellables)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var cancellables = Set<AnyCancellable>()
    }
}

class PoseOverlayView: UIView {
    var poseObservation: VNHumanBodyPoseObservation? {
        didSet {
            setNeedsDisplay()
        }
    }
    weak var viewModel: CameraViewModel?
    // Ideal pose kuda-kuda (koordinat normalisasi, tengah layar)
    let idealPose: [VNHumanBodyPoseObservation.JointName: CGPoint] = [
        .leftShoulder: CGPoint(x: 0.35, y: 0.8),
        .rightShoulder: CGPoint(x: 0.65, y: 0.8),
        .leftElbow: CGPoint(x: 0.3, y: 0.65),
        .rightElbow: CGPoint(x: 0.7, y: 0.65),
        .leftWrist: CGPoint(x: 0.25, y: 0.5),
        .rightWrist: CGPoint(x: 0.75, y: 0.5),
        .root: CGPoint(x: 0.5, y: 0.5),
        .leftHip: CGPoint(x: 0.4, y: 0.45),
        .rightHip: CGPoint(x: 0.6, y: 0.45),
        .leftKnee: CGPoint(x: 0.38, y: 0.25),
        .rightKnee: CGPoint(x: 0.62, y: 0.25),
        .leftAnkle: CGPoint(x: 0.36, y: 0.1),
        .rightAnkle: CGPoint(x: 0.64, y: 0.1)
    ]
    let matchThreshold: CGFloat = 0.08 // threshold normalisasi (0-1), bisa diubah
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
        // Draw ideal skeleton overlay (abu-abu/transparan)
        drawSkeleton(context: context, pose: idealPose, color: UIColor.gray.withAlphaComponent(0.4), pointRadius: 0, isIdeal: true)
        // Draw user pose
        if let observation = poseObservation {
            var userPose: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for joint in idealPose.keys {
                if let point = try? observation.recognizedPoint(joint) {
                    let flippedY = 1.0 - point.location.y
                    userPose[joint] = CGPoint(x: point.location.x, y: flippedY)
                }
            }
            drawSkeleton(context: context, pose: userPose, color: nil, pointRadius: 7, isIdeal: false)
        }
    }
    // Fungsi menggambar skeleton
    private func drawSkeleton(context: CGContext, pose: [VNHumanBodyPoseObservation.JointName: CGPoint], color: UIColor?, pointRadius: CGFloat, isIdeal: Bool) {
        // Draw lines
        let lineColor = color ?? UIColor.green
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(isIdeal ? 4.0 : 3.0)
        for (joint1, joint2) in skeletonConnections {
            guard let p1 = pose[joint1], let p2 = pose[joint2] else { continue }
            let start = CGPoint(x: p1.x * bounds.width, y: p1.y * bounds.height)
            let end = CGPoint(x: p2.x * bounds.width, y: p2.y * bounds.height)
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        }
        // Draw points (hanya untuk user)
        if !isIdeal {
            for (joint, point) in pose {
                var ptColor = UIColor.yellow
                if let ideal = idealPose[joint] {
                    let dist = hypot(point.x - ideal.x, point.y - ideal.y)
                    ptColor = dist < matchThreshold ? .green : .red
                }
                context.setFillColor(ptColor.cgColor)
                let circleRect = CGRect(x: point.x * bounds.width - pointRadius, y: point.y * bounds.height - pointRadius, width: pointRadius*2, height: pointRadius*2)
                context.fillEllipse(in: circleRect)
            }
        }
    }
} 

