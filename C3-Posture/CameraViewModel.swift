import SwiftUI
import AVFoundation
import Vision
import Combine

// CameraViewModel for handling camera and pose detection
class CameraViewModel: NSObject, ObservableObject {
    // Published properties
    @Published var session = AVCaptureSession()
    @Published var isPostureGood = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var currentPoseObservation: VNHumanBodyPoseObservation?
    @Published var isPersonDetected = false
    @Published var personBoundingBox: CGRect?
    
    // Pose matching properties
    @Published var selectedReferenceImage: UIImage?
    @Published var selectedReferenceName: String = ""
    @Published var isInPoseMatchingMode: Bool = false
    @Published var referenceBodyPoseObservation: VNHumanBodyPoseObservation?
    @Published var poseMatchPercentage: Double = 0.0
    @Published var jointMatches: [VNHumanBodyPoseObservation.JointName: Bool] = [:]
    @Published var overallPoseMatchStatus: Bool = false
    
    // Private properties
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .high
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
    
    // New reference pose methods
    func setReferencePose(_ poseImage: UIImage, name: String) {
        selectedReferenceImage = poseImage
        selectedReferenceName = name
        detectPoseInReferenceImage(poseImage)
        isInPoseMatchingMode = true
        startSession() // Start camera session when entering pose matching mode
    }
    
    private func detectPoseInReferenceImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }
            guard error == nil else {
                print("Error detecting pose in reference image: \(error!.localizedDescription)")
                return
            }
            
            if let observations = request.results as? [VNHumanBodyPoseObservation], let firstPose = observations.first {
                DispatchQueue.main.async {
                    self.referenceBodyPoseObservation = firstPose
                    print("Reference pose detected successfully")
                }
            } else {
                print("No pose detected in reference image")
            }
        }
        
        do {
            try requestHandler.perform([poseRequest])
        } catch {
            print("Failed to detect pose in reference image: \(error.localizedDescription)")
        }
    }
    
    func exitPoseMatchingMode() {
        stopSession() // Stop camera session when exiting pose matching mode
        isInPoseMatchingMode = false
        selectedReferenceImage = nil
        selectedReferenceName = ""
        referenceBodyPoseObservation = nil
        poseMatchPercentage = 0.0
        jointMatches.removeAll()
        overallPoseMatchStatus = false
    }
    
    // Method to compare user pose with reference pose
    func compareWithReferencePose(_ userPose: VNHumanBodyPoseObservation) {
        guard let referencePose = referenceBodyPoseObservation else { return }
        
        // Get the normalized landmark points
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip,
            .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
        ]
        
        var matchCount = 0
        var totalJoints = 0
        var newJointMatches: [VNHumanBodyPoseObservation.JointName: Bool] = [:]
        
        for jointName in jointNames {
            do {
                let userJoint = try userPose.recognizedPoint(jointName)
                let referenceJoint = try referencePose.recognizedPoint(jointName)
                
                // Only consider joints with high confidence
                if userJoint.confidence > 0.5 && referenceJoint.confidence > 0.5 {
                    totalJoints += 1
                    
                    // Calculate distance between user and reference joint positions
                    let distance = hypot(userJoint.location.x - referenceJoint.location.x,
                                         userJoint.location.y - referenceJoint.location.y)
                    
                    // Consider a match if distance is less than threshold
                    let isMatch = distance < 0.15 // 15% of the normalized distance
                    newJointMatches[jointName] = isMatch
                    
                    if isMatch {
                        matchCount += 1
                    }
                }
            } catch {
                // Joint not detected in one of the poses
                continue
            }
        }
        
        // Calculate percentage match
        let percentage = totalJoints > 0 ? Double(matchCount) / Double(totalJoints) * 100.0 : 0.0
        
        DispatchQueue.main.async {
            self.jointMatches = newJointMatches
            self.poseMatchPercentage = percentage
            self.overallPoseMatchStatus = percentage >= 70.0 // Consider a good match if >= 70%
        }
    }
    
    // Analyze posture angles
    func analyzePosture(_ observation: VNHumanBodyPoseObservation) {
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let leftElbow = try? observation.recognizedPoint(.leftElbow),
              let leftWrist = try? observation.recognizedPoint(.leftWrist),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              let rightElbow = try? observation.recognizedPoint(.rightElbow),
              let rightWrist = try? observation.recognizedPoint(.rightWrist) else {
            return
        }

        let leftArmAngle = angleBetween(p1: leftShoulder.location, 
                                     vertex: leftElbow.location, 
                                     p3: leftWrist.location)
        
        let rightArmAngle = angleBetween(p1: rightShoulder.location, 
                                       vertex: rightElbow.location, 
                                       p3: rightWrist.location)

        let targetArmAngle: CGFloat = 170
        let tolerance: CGFloat = 10

        let leftIsGood = abs(leftArmAngle - targetArmAngle) < tolerance
        let rightIsGood = abs(rightArmAngle - targetArmAngle) < tolerance

        DispatchQueue.main.async {
            self.isPostureGood = leftIsGood && rightIsGood
        }
    }

    // Calculate angle between three points
    private func angleBetween(p1: CGPoint, vertex: CGPoint, p3: CGPoint) -> CGFloat {
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p3.x - vertex.x, dy: p3.y - vertex.y)
        
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        
        let angle = acos(dot / (mag1 * mag2))
        return angle * 180 / .pi
    }
    
    // Helper for distance calculation
    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx*dx + dy*dy)
    }
}

// MARK: - Video Processing Delegate
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let orientation: CGImagePropertyOrientation
        if cameraPosition == .front {
            orientation = .leftMirrored
        } else {
            orientation = .right
        }
        
        // Setup Vision requests
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
                    
                    if self.isInPoseMatchingMode {
                        self.poseMatchPercentage = 0.0
                        self.overallPoseMatchStatus = false
                    }
                }
                return
            }
            
            // Helper functions for matching
            func boxCenter(_ box: CGRect) -> CGPoint {
                CGPoint(x: box.midX, y: box.midY)
            }
            
            func poseCenter(_ pose: VNHumanBodyPoseObservation) -> CGPoint? {
                if let left = try? pose.recognizedPoint(.leftShoulder),
                   let right = try? pose.recognizedPoint(.rightShoulder) {
                    return CGPoint(x: (left.location.x + right.location.x)/2, 
                                 y: (left.location.y + right.location.y)/2)
                } else if let neck = try? pose.recognizedPoint(.neck) {
                    return neck.location
                }
                return nil
            }
            
            // Select person and pose
            var selectedBox: CGRect? = nil
            var selectedPose: VNHumanBodyPoseObservation? = nil
            
            let best = personObservations.max { $0.confidence < $1.confidence }
            selectedBox = best?.boundingBox
            
            if let bestBox = selectedBox {
                selectedPose = poseObservations.min(by: {
                    guard let c0 = poseCenter($0), let c1 = poseCenter($1) else { return false }
                    let d0 = distance(boxCenter(bestBox), c0)
                    let d1 = distance(boxCenter(bestBox), c1)
                    return d0 < d1
                })
            }
            
            // Update UI in main thread
            DispatchQueue.main.async {
                self.isPersonDetected = selectedBox != nil
                self.personBoundingBox = selectedBox
                self.currentPoseObservation = selectedPose
                
                if let pose = selectedPose {
                    if self.isInPoseMatchingMode && self.referenceBodyPoseObservation != nil {
                        // In pose matching mode, compare with reference
                        self.compareWithReferencePose(pose)
                    } else {
                        // Standard posture analysis
                        self.analyzePosture(pose)
                    }
                } else {
                    self.isPostureGood = false
                    if self.isInPoseMatchingMode {
                        self.poseMatchPercentage = 0.0
                        self.overallPoseMatchStatus = false
                    }
                }
            }
            
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
    }
} 