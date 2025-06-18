//
//  LatihanView.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import SwiftUI
import Vision
import UIKit

struct LatihanView: View {
    var navigate: (AppRoute) -> Void
    var close: () -> Void
    let poseData: [PoseData] = PoseLoader.loadPose()
    @Environment(\.dismiss) var dismiss
    @State private var showTutorial = false
    @State private var cameraVM = CameraViewModel()
    @State private var poseViewModel = PoseEstimationViewModel()

    @State private var wasAtOptimalDistance: Bool = true
    
    // Pose matching states
    @State private var currentPoseIndex: Int = 0
    @State private var isPoseMatched: Bool = false
    @State private var holdTimer: Timer?
    @State private var holdProgress: Double = 0.0
    @State private var showCompletionMessage: Bool = false
    @State private var countdownValue: Int = 8
    @State private var lastVoiceInstructionTime: Date = Date()
    @State private var toleranceTimer: Timer?
    @State private var poseFailedTime: Date?
    @State private var showPoseTransition: Bool = false
    @State private var isProcessingVoice: Bool = false
    @State private var lastCorrectionTime: Date = Date.distantPast
    


    private let holdDuration: Double = 8.0 // 8 seconds
    private let poseMatchThreshold: Double = 0.1 // Significantly reduced for very high accuracy requirements
    private let voiceInstructionInterval: TimeInterval = 4.0 // Minimum 4 seconds between voice instructions
    private let poseTolerance: TimeInterval = 0.1 // Further reduced for even stricter pose maintenance
    private let correctionGracePeriod: TimeInterval = 2.0 // Grace period after correction before allowing pose match
    
    private func checkAndAnnounceDistance() {
        guard !isProcessingVoice else { return }
        
        if !isAtOptimalDistance && wasAtOptimalDistance {
            isProcessingVoice = true
            VoiceHelper.shared.speak("Pastikan seluruh tubuh terlihat")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isProcessingVoice = false
            }
        }
        wasAtOptimalDistance = isAtOptimalDistance
    }

    // Add computed property to check joint visibility
    private var isAtOptimalDistance: Bool {
        let requiredJoints: [HumanBodyPoseObservation.JointName] = [
            .nose, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        
        // Check if all required joints are detected with high confidence
        return requiredJoints.allSatisfy { joint in
            poseViewModel.detectedBodyParts[joint] != nil
        }
    }
    
    // Convert HumanBodyPoseObservation.JointName to poseData joint key
    private func jointNameToKey(_ jointName: HumanBodyPoseObservation.JointName) -> String {
        switch jointName {
        case .nose: return "nose"
        case .neck: return "neck"
        case .leftShoulder: return "leftShoulder"
        case .rightShoulder: return "rightShoulder"
        case .leftElbow: return "leftElbow"
        case .rightElbow: return "rightElbow"
        case .leftWrist: return "leftWrist"
        case .rightWrist: return "rightWrist"
        case .leftHip: return "leftHip"
        case .rightHip: return "rightHip"
        case .leftKnee: return "leftKnee"
        case .rightKnee: return "rightKnee"
        case .leftAnkle: return "leftAnkle"
        case .rightAnkle: return "rightAnkle"
        default: return ""
        }
    }
    
    // Convert joint name to Indonesian instruction
    private func jointNameToIndonesian(_ jointName: HumanBodyPoseObservation.JointName) -> String {
        switch jointName {
        case .nose: return "hidung"
        case .neck: return "leher"
        case .leftShoulder: return "bahu kiri"
        case .rightShoulder: return "bahu kanan"
        case .leftElbow: return "siku kiri"
        case .rightElbow: return "siku kanan"
        case .leftWrist: return "pergelangan tangan kiri"
        case .rightWrist: return "pergelangan tangan kanan"
        case .leftHip: return "pinggul kiri"
        case .rightHip: return "pinggul kanan"
        case .leftKnee: return "lutut kiri"
        case .rightKnee: return "lutut kanan"
        case .leftAnkle: return "pergelangan kaki kiri"
        case .rightAnkle: return "pergelangan kaki kanan"
        default: return ""
        }
    }
    
    // Calculate distance between two points
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // Calculate body dimensions for adaptive pose matching
    private func calculateBodyDimensions() -> (height: Double, center: CGPoint, valid: Bool) {
        // Need at least neck and one ankle for a reasonable height estimate
        guard let neck = poseViewModel.detectedBodyParts[.neck],
              let leftAnkle = poseViewModel.detectedBodyParts[.leftAnkle] ?? poseViewModel.detectedBodyParts[.rightAnkle] else {
            return (1.0, CGPoint(x: 0.5, y: 0.5), false)
        }
        
        // Calculate body height
        let bodyHeight = abs(neck.y - leftAnkle.y)
        
        // Find center point
        var centerX: CGFloat = 0.5
        var centerY: CGFloat = 0.5
        
        if let leftHip = poseViewModel.detectedBodyParts[.leftHip], 
           let rightHip = poseViewModel.detectedBodyParts[.rightHip] {
            centerX = (leftHip.x + rightHip.x) / 2
            centerY = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = poseViewModel.detectedBodyParts[.leftHip] ?? poseViewModel.detectedBodyParts[.rightHip] {
            centerX = singleHip.x
            centerY = singleHip.y
        } else if let neckPos = poseViewModel.detectedBodyParts[.neck] {
            centerX = neckPos.x
            centerY = neckPos.y + 0.15
        }
        
        return (bodyHeight, CGPoint(x: centerX, y: centerY), true)
    }
    
    // Transform target pose point to match user's proportions
    private func transformTargetPoint(_ targetPoint: CGPoint, userDimensions: (height: Double, center: CGPoint, valid: Bool), targetReferences: (height: Double, center: CGPoint)) -> CGPoint {
        guard userDimensions.valid else { return targetPoint }
        
        // Get additional reference measurements for aspect ratio adjustment
        let targetPose = poseData[currentPoseIndex]
        
        // Calculate shoulder width for aspect ratio adjustment
        var targetShoulderWidth: CGFloat = 0.15 // Default if not found
        if let leftShoulder = targetPose.joints["leftShoulder"], 
           let rightShoulder = targetPose.joints["rightShoulder"] {
            targetShoulderWidth = abs(leftShoulder.x - rightShoulder.x)
        }
        
        // Get user's shoulder width
        var userShoulderWidth: CGFloat = 0.15
        if let leftShoulder = poseViewModel.detectedBodyParts[.leftShoulder],
           let rightShoulder = poseViewModel.detectedBodyParts[.rightShoulder] {
            userShoulderWidth = abs(leftShoulder.x - rightShoulder.x)
        }
        
        // Scale and shift the target point with separate horizontal and vertical scaling
        let verticalScaleFactor = (targetReferences.height > 0.01) ? userDimensions.height / targetReferences.height : 1.0
        
        // Calculate horizontal scale factor - make it wider by multiplying by 1.25
        let horizontalScaleFactor = (targetShoulderWidth > 0.01) ? 
            (userShoulderWidth / targetShoulderWidth) * 1.25 : verticalScaleFactor * 1.25
        
        // Calculate the adjusted position with separate horizontal and vertical scaling
        let relativeX = targetPoint.x - targetReferences.center.x
        let relativeY = targetPoint.y - targetReferences.center.y
        
        let adjustedX = userDimensions.center.x + relativeX * horizontalScaleFactor
        let adjustedY = userDimensions.center.y + relativeY * verticalScaleFactor
        
        // Keep points within bounds
        let boundedX = min(max(adjustedX, 0.01), 0.99)
        let boundedY = min(max(adjustedY, 0.01), 0.99)
        
        return CGPoint(x: boundedX, y: boundedY)
    }
    
    // Get target pose reference dimensions
    private func getTargetPoseReferences() -> (height: Double, center: CGPoint) {
        guard currentPoseIndex < poseData.count else { return (1.0, CGPoint(x: 0.5, y: 0.5)) }
        
        let targetPose = poseData[currentPoseIndex]
        
        // Get reference points
        var targetNeckY: CGFloat = 0.3
        var targetAnkleY: CGFloat = 0.9
        var targetCenter = CGPoint(x: 0.5, y: 0.5)
        
        if let neckJoint = targetPose.joints["neck"] {
            targetNeckY = neckJoint.y
        }
        
        if let leftAnkle = targetPose.joints["leftAnkle"] ?? targetPose.joints["rightAnkle"] {
            targetAnkleY = leftAnkle.y
        }
        
        // Calculate target height
        let targetHeight = abs(targetAnkleY - targetNeckY)
        
        // Calculate center
        if let leftHip = targetPose.joints["leftHip"], let rightHip = targetPose.joints["rightHip"] {
            targetCenter.x = (leftHip.x + rightHip.x) / 2
            targetCenter.y = (leftHip.y + rightHip.y) / 2
        } else if let singleHip = targetPose.joints["leftHip"] ?? targetPose.joints["rightHip"] {
            targetCenter.x = singleHip.x
            targetCenter.y = singleHip.y
        }
        
        return (targetHeight, targetCenter)
    }
    
    // Check if current pose matches target pose
    private func checkPoseMatch() -> Bool {
        guard currentPoseIndex < poseData.count else { return false }
        
        let targetPose = poseData[currentPoseIndex]
        var totalDistance: Double = 0
        var validJoints = 0
        
        // Get body dimensions for adaptive matching
        let userDimensions = calculateBodyDimensions()
        let targetReferences = getTargetPoseReferences()
        
        for (jointName, detectedPoint) in poseViewModel.detectedBodyParts {
            let jointKey = jointNameToKey(jointName)
            
            if let targetJoint = targetPose.joints[jointKey] {
                let targetPoint = CGPoint(x: targetJoint.x, y: targetJoint.y)
                
                // Apply adaptive scaling to target point if valid user dimensions
                let adjustedTargetPoint = userDimensions.valid ? 
                    transformTargetPoint(targetPoint, userDimensions: userDimensions, targetReferences: targetReferences) : targetPoint
                
                let dist = distance(detectedPoint, adjustedTargetPoint)
                totalDistance += dist
                validJoints += 1
            }
        }
        
        guard validJoints > 0 else { return false }
        
        let averageDistance = totalDistance / Double(validJoints)
        return averageDistance < poseMatchThreshold
    }
    
    // Give voice instruction for worst positioned joint
    private func giveJointCorrection() {
        guard currentPoseIndex < poseData.count,
              Date().timeIntervalSince(lastVoiceInstructionTime) >= voiceInstructionInterval,
              !isProcessingVoice,
              !isPoseMatched else { return }
        
        let targetPose = poseData[currentPoseIndex]
        var worstJoint: HumanBodyPoseObservation.JointName?
        var maxDistance: Double = 0
        
        for (jointName, detectedPoint) in poseViewModel.detectedBodyParts {
            let jointKey = jointNameToKey(jointName)
            
            if let targetJoint = targetPose.joints[jointKey] {
                let targetPoint = CGPoint(x: targetJoint.x, y: targetJoint.y)
                let dist = distance(detectedPoint, targetPoint)
                
                if dist > maxDistance && dist > 0.15 { // Only consider significant differences
                    maxDistance = dist
                    worstJoint = jointName
                }
            }
        }
        
        if let joint = worstJoint, maxDistance > 0.15 {
            let jointIndonesian = jointNameToIndonesian(joint)
            
            // Determine direction based on position difference
            let jointKey = jointNameToKey(joint)
            if let targetJoint = targetPose.joints[jointKey],
               let currentPoint = poseViewModel.detectedBodyParts[joint] {
                let targetPoint = CGPoint(x: targetJoint.x, y: targetJoint.y)
                
                var instruction = jointIndonesian
                
                // Determine vertical movement
                if currentPoint.y > targetPoint.y + 0.05 {
                    instruction += " kurang naik"
                } else if currentPoint.y < targetPoint.y - 0.05 {
                    instruction += " kurang turun"
                }
                
                // Determine horizontal movement
                // if currentPoint.x > targetPoint.x + 0.05 {
                //     instruction += currentPoint.y != targetPoint.y ? " dan" : ""
                //     instruction += " kurang ke kiri"
                // } else if currentPoint.x < targetPoint.x - 0.05 {
                //     instruction += currentPoint.y != targetPoint.y ? " dan" : ""
                //     instruction += " kurang ke kanan"
                // }
                
                isProcessingVoice = true
                VoiceHelper.shared.speak(instruction)
                lastVoiceInstructionTime = Date()
                lastCorrectionTime = Date()  // Record correction time
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isProcessingVoice = false
                }
            }
        }
    }
    
    // Handle pose matching and progression
    private func handlePoseMatching() {
        guard !showPoseTransition else { return }
        
        // Check if we're still in grace period after correction
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        let isInGracePeriod = timeSinceCorrection < correctionGracePeriod
        
        let poseMatches = isAtOptimalDistance && checkPoseMatch()
        
        if poseMatches && !isInGracePeriod {
            // Only allow pose match if not in grace period
            // Reset tolerance timer since pose is correct
            toleranceTimer?.invalidate()
            toleranceTimer = nil
            poseFailedTime = nil
            
            if !isPoseMatched {
                // Start holding timer
                isPoseMatched = true
                countdownValue = 3
                startHoldTimer()
                
                if !isProcessingVoice {
                    isProcessingVoice = true
                    VoiceHelper.shared.speak("Pose benar, tahan posisi")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isProcessingVoice = false
                    }
                }
            }
        } else {
            // Pose doesn't match or still in grace period
            if isPoseMatched {
                // We were in holding state but pose became incorrect
                if poseFailedTime == nil {
                    // Start tolerance timer
                    poseFailedTime = Date()
                } else {
                    // Check if tolerance time has passed
                    if Date().timeIntervalSince(poseFailedTime!) >= poseTolerance {
                        // Tolerance exceeded, reset the pose
                        resetHoldTimer()
                    }
                }
            } else if isAtOptimalDistance && !isInGracePeriod {
                // Give correction instruction (not in holding state and not in grace period)
                giveJointCorrection()
            }
        }
    }
    
    private func startHoldTimer() {
        holdProgress = 0.0
        countdownValue = 8
        
        // Announce initial countdown immediately
        if !isProcessingVoice {
            isProcessingVoice = true
            VoiceHelper.shared.speak("8")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isProcessingVoice = false
            }
        }
        
        // Stop any existing timer first
        holdTimer?.invalidate()
        
        var elapsedTime: Double = 0.0
        let checkInterval: Double = 0.1 // Check every 0.1 seconds for smoother validation
        var lastAnnouncedSecond: Int = 8 // Track the last announced second
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { timer in
            // Check if we're still in grace period
            let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
            let isInGracePeriod = timeSinceCorrection < correctionGracePeriod
            
            // Check if pose is still correct every 0.1 seconds during countdown
            if isAtOptimalDistance && checkPoseMatch() && !isInGracePeriod {
                // Pose is still correct and not in grace period, update progress
                elapsedTime += checkInterval
                holdProgress = elapsedTime / 8.0
                
                // Update countdown value at each second
                let currentSecond = 8 - Int(elapsedTime)
                countdownValue = max(currentSecond, 1) // Don't go below 1
                
                // Announce each second, ensuring we don't repeat announcements
                if currentSecond < lastAnnouncedSecond && currentSecond >= 1 {
                    lastAnnouncedSecond = currentSecond
                    
                    // Queue the announcement, even if voice is processing
                    DispatchQueue.main.async {
                        if !isProcessingVoice {
                            isProcessingVoice = true
                            VoiceHelper.shared.speak("\(currentSecond)")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isProcessingVoice = false
                            }
                        } else {
                            // If we're currently speaking, queue this announcement with a slight delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                isProcessingVoice = true
                                VoiceHelper.shared.speak("\(currentSecond)")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isProcessingVoice = false
                                }
                            }
                        }
                    }
                }
                
                // Complete after 8 seconds
                if elapsedTime >= 8.0 {
                    holdProgress = 1.0
                    timer.invalidate()  // Stop the timer
                    completeCurrentPose()
                }
            } else {
                // Pose became incorrect during countdown or in grace period
                timer.invalidate()  // Stop the timer immediately
                
                if poseFailedTime == nil {
                    poseFailedTime = Date()
                } else if Date().timeIntervalSince(poseFailedTime!) >= poseTolerance {
                    // Tolerance exceeded during countdown
                    resetHoldTimer()
                }
            }
        }
    }
    
    private func stopHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        toleranceTimer?.invalidate()
        toleranceTimer = nil
        holdProgress = 0.0
        countdownValue = 8
        poseFailedTime = nil
    }
    
    private func resetHoldTimer() {
        // Reset with specific voice feedback for pose failure
        stopHoldTimer()
        isPoseMatched = false
        
        if !isProcessingVoice {
            isProcessingVoice = true
            VoiceHelper.shared.speak("Pose salah, ulangi lagi")
            lastVoiceInstructionTime = Date()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isProcessingVoice = false
            }
        }
    }
    
    private func completeCurrentPose() {
        stopHoldTimer()
        isPoseMatched = false
        
        if currentPoseIndex < poseData.count - 1 {
            // Show transition screen before moving to next pose
            showPoseTransition = true
            
            if !isProcessingVoice {
                isProcessingVoice = true
                VoiceHelper.shared.speak("Bagus! Lanjut ke gerakan berikutnya")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isProcessingVoice = false
                }
            }
            
            // Wait 2 seconds then move to next pose
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                currentPoseIndex += 1
                showPoseTransition = false
            }
        } else {
            // All poses completed
            showCompletionMessage = true
            if !isProcessingVoice {
                isProcessingVoice = true
                VoiceHelper.shared.speak("Selamat! Semua gerakan telah diselesaikan")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isProcessingVoice = false
                }
            }
        }
    }
    
    // Get current target pose
    private var currentTargetPose: PoseData? {
        guard currentPoseIndex < poseData.count else { return nil }
        return poseData[currentPoseIndex]
    }
    
    var body: some View {
            ZStack {
                CameraPreviewView(session: cameraVM.session)
                    .ignoresSafeArea()
                
                PoseOverlayView(
                    bodyParts: poseViewModel.detectedBodyParts,
                    connections: poseViewModel.bodyConnections,
                    targetPose: currentTargetPose,
                    showGuideArrows: isAtOptimalDistance && !isPoseMatched && !showPoseTransition
                )
                
                VStack {
                    HStack {
                        Button(action: {
                            showTutorial = true
                        }) {
                            Image(systemName: "info.circle")
                                .padding(.leading, 37)
                        }
                    .fullScreenCover(isPresented: $showTutorial) {
                        TutorialView(navigate: navigate)
                    }
                        
                        Spacer()
                        
                        Button(action: {
                            close()
                        }) {
                            Image(systemName: "x.circle")
                                .padding(.trailing, 37)
                        }
                        
                    }
                    .font(.system(size: 32.25, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.vertical, 4)
                    
                    Text("Jurus 1")
                        .font(.system(size: 32, weight: .bold))
                    
                    // Show current pose progress
                    Text("A\(currentPoseIndex + 1) / A\(poseData.count)")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.gray.opacity(0.14))
                        )
                    
                    Spacer()
                    
                    // Pose status indicator
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: isAtOptimalDistance ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(isAtOptimalDistance ? .green : .orange)
                            Text(isAtOptimalDistance ? "Posisi Optimal" : "Sesuaikan Jarak")
                                .foregroundColor(isAtOptimalDistance ? .green : .orange)
                        }
                        .font(.system(size: 18, weight: .medium))
                        
                        // Pose matching indicator
                        if isAtOptimalDistance && !showPoseTransition {
                            HStack {
                                Image(systemName: isPoseMatched ? "checkmark.circle.fill" : "target")
                                    .foregroundColor(isPoseMatched ? .green : .blue)
                                Text(isPoseMatched ? "Pose Cocok - Tahan!" : "Sesuaikan Pose")
                                    .foregroundColor(isPoseMatched ? .green : .blue)
                            }
                            .font(.system(size: 16, weight: .medium))
                            
                            // Hold progress bar and countdown
                            if isPoseMatched {
                                VStack(spacing: 8) {
                                    Text("\(countdownValue)")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.green)
                                    
                                    ProgressView(value: holdProgress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                        .frame(width: 200)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.8))
                    )
                    
                    Text("Sesuaikan Posisi Anda di dalam Kotak")
                        .font(.system(size: 18, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 50)
                        .padding(.horizontal, 48)
                    
                    Button(action: {
                        navigate(.finish)
                    }) {
                        Text(showCompletionMessage ? "Selesai" : "Lewati")
                    }
                }
                .opacity(showPoseTransition ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: showPoseTransition)
                
                // Pose transition overlay
                if showPoseTransition {
                    PoseTransitionView(
                        poseNumber: currentPoseIndex + 2,
                        targetPose: currentPoseIndex + 1 < poseData.count ? poseData[currentPoseIndex + 1] : nil
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                // Disable screen idle timer to prevent screen dimming
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                // Re-enable screen idle timer when leaving the view
                UIApplication.shared.isIdleTimerDisabled = false
                // Clean up all timers
                stopHoldTimer()
            }
            .task {
              await cameraVM.checkPermission()
              cameraVM.delegate = poseViewModel
            }
            .onChange(of: isAtOptimalDistance) { _, _ in
              checkAndAnnounceDistance()
            }
            .onChange(of: poseViewModel.detectedBodyParts) { _, _ in
              handlePoseMatching()
            }
        }
    }

// Pose transition view
struct PoseTransitionView: View {
    let poseNumber: Int
    let targetPose: PoseData?
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Gerakan Berikutnya")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("A\(poseNumber)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.yellow)
                
                // Show preview of next pose
                if targetPose != nil {
                    Image("silat_a")  // You can dynamically load based on pose
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 40)
                }
                
                Text("Siap dalam...")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("2")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.green)
            }
        }
    }
}

