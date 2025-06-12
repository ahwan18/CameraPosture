import Foundation
import AVFoundation
import Vision
import Combine

class CameraService: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var currentFrame: CVPixelBuffer?
    @Published var detectedPose: DetectedPose?
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    
    let session = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.silattrainer.camera")
    private let poseDetectionQueue = DispatchQueue(label: "com.silattrainer.posedetection")
    
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    private var lastPoseDetectionTime: Date = Date()
    
    override init() {
        super.init()
        checkCameraPermission()
        setupPoseDetection()
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionStatus = .authorized
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.cameraPermissionStatus = granted ? .authorized : .denied
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            cameraPermissionStatus = .denied
        @unknown default:
            break
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Setup front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            deviceInput = input
        }
        
        // Setup video output
        videoOutput.setSampleBufferDelegate(self, queue: poseDetectionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            // Set video orientation for front camera
            if let connection = videoOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = true
            }
        }
        
        session.commitConfiguration()
    }
    
    private func setupPoseDetection() {
        poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            if let error = error {
                print("Pose detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else { return }
            
            self?.processPoseObservation(observation)
        }
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPoseObservation) {
        do {
            let recognizedPoints = try observation.recognizedPoints(.all)
            var joints: [JointName: CGPoint] = [:]
            
            for (vnJointName, point) in recognizedPoints {
                guard let jointName = JointName.from(vnJoint: vnJointName),
                      point.confidence > TrainingConfig.minimumJointConfidence else { continue }
                
                // Convert Vision coordinates (bottom-left origin) to UI coordinates (top-left origin)
                let normalizedPoint = CGPoint(
                    x: point.location.x,
                    y: 1.0 - point.location.y
                )
                
                joints[jointName] = normalizedPoint
            }
            
            let detectedPose = DetectedPose(joints: joints, timestamp: Date())
            
            DispatchQueue.main.async {
                self.detectedPose = detectedPose
            }
            
        } catch {
            print("Error processing pose observation: \(error)")
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let currentInput = self.deviceInput else { return }
            
            self.session.beginConfiguration()
            self.session.removeInput(currentInput)
            
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .front ? .back : .front
            
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera) else {
                self.session.addInput(currentInput)
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.deviceInput = newInput
                
                // Update video orientation
                if let connection = self.videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                    connection.isVideoMirrored = newPosition == .front
                }
            } else {
                self.session.addInput(currentInput)
            }
            
            self.session.commitConfiguration()
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Update current frame for preview
        DispatchQueue.main.async {
            self.currentFrame = pixelBuffer
        }
        
        // Throttle pose detection to specified frame rate
        let now = Date()
        let timeSinceLastDetection = now.timeIntervalSince(lastPoseDetectionTime)
        let detectionInterval = 1.0 / TrainingConfig.poseDetectionFrameRate
        
        guard timeSinceLastDetection >= detectionInterval else { return }
        lastPoseDetectionTime = now
        
        // Perform pose detection
        guard let poseRequest = poseRequest else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([poseRequest])
        } catch {
            print("Failed to perform pose detection: \(error)")
        }
    }
} 