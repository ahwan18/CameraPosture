//
//  CameraManager.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import SwiftUI
import AVFoundation
import Vision

class CameraManager: CameraServiceProtocol {
    static let shared = CameraManager()
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let videoDataOutputQueue = DispatchQueue(label: "videoDataOutputQueue")
    private let videoDataOutput = AVCaptureVideoDataOutput()
    var frameDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    private init() {}
    
    func setupCamera() async -> Bool {
        var success = false
        
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                self.session.beginConfiguration()
                
                guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                      let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                    print("Failed to create video input")
                    self.session.commitConfiguration()
                    continuation.resume(returning: ())
                    return
                }
                
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                }
                
                self.videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                
                if let delegate = self.frameDelegate {
                    self.videoDataOutput.setSampleBufferDelegate(delegate, queue: self.videoDataOutputQueue)
                }
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                
                if self.session.canAddOutput(self.videoDataOutput) {
                    self.session.addOutput(self.videoDataOutput)
                }
                
                if let connection = self.videoDataOutput.connection(with: .video) {
                    connection.videoRotationAngle = 90
                    connection.isVideoMirrored = true
                }
                
                self.session.commitConfiguration()
                success = true
                continuation.resume(returning: ())
            }
        }
        
        return success
    }
    
    func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            print("Camera permission denied")
            return false
        }
    }
    
    func startCapture() {
        sessionQueue.async {
            self.session.startRunning()
        }
    }
    
    func stopCapture() {
        sessionQueue.async {
            self.session.stopRunning()
        }
    }
    
    func processPoseFromBuffer(_ buffer: CMSampleBuffer) async -> [HumanBodyPoseObservation.JointName: CGPoint]? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
        
        let request = DetectHumanBodyPoseRequest()
        
        do {
            let results = try await request.perform(on: imageBuffer, orientation: .none)
            if let observation = results.first {
                return extractPoints(from: observation)
            }
        } catch {
            print("Error processing frame: \(error.localizedDescription)")
        }

        return nil
    }
    
    private func extractPoints(from observation: HumanBodyPoseObservation) -> [HumanBodyPoseObservation.JointName: CGPoint] {
        var detectedPoints: [HumanBodyPoseObservation.JointName: CGPoint] = [:]
        let humanJoints: [HumanBodyPoseObservation.PoseJointsGroupName] = [.face, .torso, .leftArm, .rightArm, .leftLeg, .rightLeg]
        
        for groupName in humanJoints {
            let jointsInGroup = observation.allJoints(in: groupName)
            for (jointName, joint) in jointsInGroup {
                if joint.confidence > 0.5 { // Ensuring only high-confidence joints are added
                    let point = joint.location.verticallyFlipped().cgPoint
                    detectedPoints[jointName] = point
                }
            }
        }
        return detectedPoints
    }
} 