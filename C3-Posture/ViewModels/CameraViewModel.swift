import SwiftUI
import AVFoundation
import Vision
import Combine

// Protocol for sequential training delegate
protocol SequentialTrainingDelegate: AnyObject {
    func userLeftPositioningBox()
    func positioningCompleted()
}

// CameraViewModel for handling camera and pose detection
class CameraViewModel: NSObject, ObservableObject {
    // Published properties
    @Published var session = AVCaptureSession()
    @Published var isPostureGood = false
    @Published var cameraPosition: AVCaptureDevice.Position = .front
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
    
    // Enhanced positioning box properties
    @Published var showPositioningBox: Bool = true
    @Published var isUserInPositioningBox: Bool = false
    @Published var userDistanceFromCamera: Double = 0.0
    @Published var canStartPoseMatching: Bool = false
    @Published var shouldContinuouslyMonitorPosition: Bool = false
    @Published var positioningTimer: Double = 0.0
    @Published var positioningProgress: Double = 0.0
    @Published var isStabilizingPosition: Bool = false
    @Published var hasCompletedInitialPositioning: Bool = false // Track if initial positioning is done
    
    // Sequential training reset delegate
    weak var sequentialTrainingDelegate: SequentialTrainingDelegate?
    
    // Private properties
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    
    // Enhanced positioning constants
    private let optimalDistance: Double = 3.0 // 3 meters
    private let distanceTolerance: Double = 0.3 // 30cm tolerance
    private let minBodyHeightRatio: CGFloat = 0.25 // More forgiving minimum for 3m distance
    private let maxBodyHeightRatio: CGFloat = 0.85 // More forgiving maximum for 3m distance
    private let requiredPositioningTime: Double = 3.0 // Must be positioned for 3 seconds
    private let outOfFrameGracePeriod: Double = 2.0 // 2 seconds grace period
    
    // Positioning stability tracking
    private var positioningStabilityTimer: Timer?
    private var outOfFrameTimer: Timer?
    private var lastPositionCheck: Date = Date()
    private var consecutiveGoodPositions: Int = 0
    private var consecutiveBadPositions: Int = 0
    
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
    
    // Front camera only - no switching allowed
    func switchCamera() {
        // Do nothing - only front camera allowed
        print("Camera switching disabled - using front camera only")
    }
    
    func startSession() {
        if !session.isRunning {
            print("📹 Starting camera session...")
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
                DispatchQueue.main.async {
                    print("📹 Camera session started: \(self.session.isRunning)")
                }
            }
        } else {
            print("📹 Camera session already running")
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    // New reference pose methods
    func setReferencePose(_ poseImage: UIImage, name: String, enableContinuousMonitoring: Bool = false) {
        print("🎯 Setting reference pose: \(name)")
        selectedReferenceImage = poseImage
        selectedReferenceName = name
        detectPoseInReferenceImage(poseImage)
        isInPoseMatchingMode = true
        shouldContinuouslyMonitorPosition = enableContinuousMonitoring
        
        // Only show positioning box if this is the initial positioning
        if !hasCompletedInitialPositioning {
            print("🔄 First pose - showing positioning box")
            showPositioningBox = true
            canStartPoseMatching = false
            // Reset positioning state for initial setup
            resetPositioningState()
        } else {
            print("✅ Subsequent pose - skipping positioning box (already positioned)")
            showPositioningBox = false
            canStartPoseMatching = true // User is already positioned, can start immediately
        }
        
        print("📊 State - ShowBox: \(showPositioningBox), CanStart: \(canStartPoseMatching), InitialDone: \(hasCompletedInitialPositioning)")
        
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
        showPositioningBox = true
        canStartPoseMatching = false
        isUserInPositioningBox = false
        shouldContinuouslyMonitorPosition = false
        hasCompletedInitialPositioning = false // Reset for next session
        sequentialTrainingDelegate = nil
        
        // Clean up positioning timers
        resetPositioningState()
    }
    
    // Enhanced stable positioning analysis
    func analyzeUserPositioning(_ observation: VNHumanBodyPoseObservation, boundingBox: CGRect) {
        // Calculate body height ratio based on detected pose
        let bodyHeightRatio = calculateBodyHeightRatio(observation, boundingBox: boundingBox)
        
        // Check if user is within positioning criteria
        let isWithinOptimalRange = bodyHeightRatio >= minBodyHeightRatio && bodyHeightRatio <= maxBodyHeightRatio
        let isBodyCentered = isBodyCenteredInFrame(boundingBox)
        let isFullBodyVisible = isFullBodyVisible(observation)
        
        let currentlyInBox = isWithinOptimalRange && isBodyCentered && isFullBodyVisible
        
        // CRITICAL BUG FIX: Reduce debug verbosity for performance
        // Only log when status changes
        if currentlyInBox != isUserInPositioningBox {
            print("📏 Positioning: \(currentlyInBox ? "✅" : "❌") (Height: \(String(format: "%.2f", bodyHeightRatio)), Centered: \(isBodyCentered), Full: \(isFullBodyVisible))")
        }
        
        DispatchQueue.main.async {
            self.handlePositioningLogic(currentlyInBox: currentlyInBox)
        }
    }
    
    // MARK: - Enhanced Positioning Logic
    
    private func handlePositioningLogic(currentlyInBox: Bool) {
        let wasInBox = isUserInPositioningBox
        isUserInPositioningBox = currentlyInBox
        
        // CRITICAL BUG FIX: Only log significant state changes
        if currentlyInBox != wasInBox {
            print("🔍 Position change: \(currentlyInBox ? "IN" : "OUT") - ShowBox: \(showPositioningBox), CanStart: \(canStartPoseMatching)")
        }
        
        if currentlyInBox {
            consecutiveGoodPositions += 1
            consecutiveBadPositions = 0
            
            // Cancel any out-of-frame timer since user is back
            outOfFrameTimer?.invalidate()
            outOfFrameTimer = nil
            
            // Start positioning stabilization if we're still showing positioning box AND not already stabilizing
            if showPositioningBox && !canStartPoseMatching && !isStabilizingPosition {
                print("✅ Starting positioning stabilization...")
                startPositioningStabilization()
            } else if showPositioningBox && !canStartPoseMatching && isStabilizingPosition {
                print("⏳ Already stabilizing... timer: \(String(format: "%.1f", positioningTimer))/\(requiredPositioningTime)")
            } else {
                print("⚠️ Not starting stabilization - ShowBox: \(showPositioningBox), CanStart: \(canStartPoseMatching), IsStabilizing: \(isStabilizingPosition)")
            }
        } else {
            consecutiveBadPositions += 1
            consecutiveGoodPositions = 0
            
            print("❌ User not in box - resetting stabilization")
            
            // If user was in a good position and now isn't, start grace period
            if wasInBox && canStartPoseMatching && shouldContinuouslyMonitorPosition {
                startOutOfFrameGracePeriod()
            }
            
            // Reset positioning if we're still in setup phase
            if showPositioningBox || isStabilizingPosition {
                resetPositioningStabilization()
            }
        }
    }
    
    private func startPositioningStabilization() {
        // Only start if not already stabilizing
        guard !isStabilizingPosition else {
            print("🚫 Positioning stabilization already in progress, not restarting")
            return
        }
        
        isStabilizingPosition = true
        positioningTimer = 0.0
        print("🚀 Starting positioning stabilization - user must hold position for \(requiredPositioningTime) seconds")
        
        // Start the timer
        positioningStabilityTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                self.positioningTimer += 0.1
                self.positioningProgress = min(self.positioningTimer / self.requiredPositioningTime, 1.0)
                
                // CRITICAL BUG FIX: Less frequent progress logging
                if Int(self.positioningTimer * 10) % 10 == 0 { // Log every second
                    print("⏰ Countdown: \(Int(self.requiredPositioningTime - self.positioningTimer + 1))")
                }
                
                if self.positioningTimer >= self.requiredPositioningTime {
                    // User has maintained good position for required time
                    print("✅ Positioning stabilization completed!")
                    timer.invalidate()
                    self.completePositioningStabilization()
                }
            }
        }
    }
    
    private func resetPositioningStabilization() {
        positioningStabilityTimer?.invalidate()
        positioningStabilityTimer = nil
        isStabilizingPosition = false
        positioningTimer = 0.0
        positioningProgress = 0.0
    }
    
    private func completePositioningStabilization() {
        resetPositioningStabilization()
        showPositioningBox = false
        canStartPoseMatching = true
        hasCompletedInitialPositioning = true // Mark initial positioning as complete
        print("🎯 Initial positioning complete - user positioned correctly!")
        print("📍 Subsequent poses will skip positioning box")
        
        // Notify that positioning is complete and training should start
        sequentialTrainingDelegate?.positioningCompleted()
    }
    
    private func startOutOfFrameGracePeriod() {
        outOfFrameTimer?.invalidate()
        print("User moved out of frame - starting \(outOfFrameGracePeriod) second grace period")
        
        outOfFrameTimer = Timer.scheduledTimer(withTimeInterval: outOfFrameGracePeriod, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Only reset if user is still out of frame after grace period
                if !self.isUserInPositioningBox && self.shouldContinuouslyMonitorPosition {
                    print("Grace period expired - resetting training session")
                    self.sequentialTrainingDelegate?.userLeftPositioningBox()
                }
            }
        }
    }
    
    private func resetPositioningState() {
        positioningStabilityTimer?.invalidate()
        positioningStabilityTimer = nil
        outOfFrameTimer?.invalidate()
        outOfFrameTimer = nil
        
        isStabilizingPosition = false
        positioningTimer = 0.0
        positioningProgress = 0.0
        consecutiveGoodPositions = 0
        consecutiveBadPositions = 0
    }
    
    private func calculateBodyHeightRatio(_ observation: VNHumanBodyPoseObservation, boundingBox: CGRect) -> CGFloat {
        // Try to get key points to calculate actual body height
        do {
            let head = try observation.recognizedPoint(.nose)
            let leftAnkle = try observation.recognizedPoint(.leftAnkle)
            let rightAnkle = try observation.recognizedPoint(.rightAnkle)
            
            if head.confidence > 0.3 && (leftAnkle.confidence > 0.3 || rightAnkle.confidence > 0.3) {
                let headY = head.location.y
                let ankleY = max(leftAnkle.confidence > 0.3 ? leftAnkle.location.y : 0,
                                rightAnkle.confidence > 0.3 ? rightAnkle.location.y : 0)
                
                // In Vision coordinates, Y is flipped, so higher Y value is actually lower on screen
                let bodyHeight = abs(headY - ankleY)
                return bodyHeight
            }
        } catch {
            // Fall back to bounding box height if pose points are not available
        }
        
        // Fallback: use bounding box height as approximation
        return boundingBox.height
    }
    
    private func isBodyCenteredInFrame(_ boundingBox: CGRect) -> Bool {
        let centerX = boundingBox.midX
        let frameCenter: CGFloat = 0.5
        let tolerance: CGFloat = 0.15 // 15% tolerance from center
        
        return abs(centerX - frameCenter) <= tolerance
    }
    
    private func isFullBodyVisible(_ observation: VNHumanBodyPoseObservation) -> Bool {
        // Check if key body parts (head to feet) are visible
        let requiredJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose,           // Head
            .leftShoulder,   // Upper body
            .rightShoulder,
            .leftHip,        // Mid body
            .rightHip,
            .leftAnkle,      // Lower body
            .rightAnkle
        ]
        
        var visibleJoints = 0
        let minConfidence: Float = 0.2  // Lower confidence threshold
        
        for joint in requiredJoints {
            do {
                let point = try observation.recognizedPoint(joint)
                if point.confidence > minConfidence {
                    visibleJoints += 1
                }
            } catch {
                continue
            }
        }
        
        // Consider full body visible if at least 4 out of 7 key joints are detected (more lenient)
        let result = visibleJoints >= 4
        // CRITICAL BUG FIX: Only log when visibility status changes
        return result
    }
    
    // Method to compare user pose with reference pose
    func compareWithReferencePose(_ userPose: VNHumanBodyPoseObservation) {
        guard let referencePose = referenceBodyPoseObservation else { return }
        
        // Only start pose matching if user is positioned correctly
        guard canStartPoseMatching else { return }
        
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
                
                // CRITICAL BUG FIX: Lower confidence threshold for better detection
                if userJoint.confidence > 0.3 && referenceJoint.confidence > 0.3 {
                    totalJoints += 1
                    
                    // Calculate distance between user and reference joint positions
                    let distance = hypot(userJoint.location.x - referenceJoint.location.x,
                                         userJoint.location.y - referenceJoint.location.y)
                    
                    // CRITICAL BUG FIX: More forgiving distance threshold
                    let isMatch = distance < 0.20 // 20% tolerance for better matching
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
            // CRITICAL BUG FIX: Set to 75% as requested by user
            let wasMatched = self.overallPoseMatchStatus
            self.overallPoseMatchStatus = percentage >= 75.0 // User requested 75% similarity
            
            // Debug log when match status changes
            if wasMatched != self.overallPoseMatchStatus {
                print("🎯 Pose Match Status Changed: \(self.overallPoseMatchStatus ? "✅ MATCHED" : "❌ NOT MATCHED") - Percentage: \(String(format: "%.1f", percentage))%")
            }
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
            
            let personObservations = personDetectionRequest.results ?? []
            let poseObservations = poseRequest.results as? [VNHumanBodyPoseObservation] ?? []
            
            if personObservations.isEmpty {
                // CRITICAL BUG FIX: Only log when person detection changes
                if self.isPersonDetected {
                    print("👤 Person lost from frame")
                }
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
                
                // CRITICAL BUG FIX: Only log when detection state changes
                let wasDetected = self.isPersonDetected
                if !wasDetected && selectedBox != nil {
                    print("🎥 Person detected in frame")
                }
                
                if let pose = selectedPose, let box = selectedBox {
                    // Analyze user positioning when positioning box is shown OR when continuously monitoring
                    if self.showPositioningBox || self.shouldContinuouslyMonitorPosition {
                        // CRITICAL BUG FIX: Remove redundant logging
                        self.analyzeUserPositioning(pose, boundingBox: box)
                    }
                    
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
                        self.isUserInPositioningBox = false
                    }
                }
            }
            
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
    }
} 
