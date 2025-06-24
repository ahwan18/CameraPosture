//
//  PoseEstimationViewModel.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 15/06/25.
//

import SwiftUI
import Vision
import AVFoundation
import Combine

/// Represents a connection between two body joints for visualization purposes
struct BodyConnection: Identifiable {
    let id = UUID()
    let from: HumanBodyPoseObservation.JointName  // Source joint
    let to: HumanBodyPoseObservation.JointName    // Target joint
}

/// View model responsible for human pose detection and skeleton visualization
class PoseEstimationViewModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {

    /// Dictionary mapping body joint names to their detected positions
    @Published var detectedBodyParts: [HumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    /// List of connections between body joints to create a skeleton visualization
    @Published var bodyConnections: [BodyConnection] = []
    
    /// Current camera frame as UIImage for capture purposes
    private(set) var currentFrame: UIImage?
    
    override init() {
        super.init()
        setupBodyConnections()
    }
    
    /// Defines the connections between body joints to form a human skeleton
    private func setupBodyConnections() {
        bodyConnections = [
            // Head and torso connections
            BodyConnection(from: .nose, to: .neck),
            BodyConnection(from: .neck, to: .rightShoulder),
            BodyConnection(from: .neck, to: .leftShoulder),
            BodyConnection(from: .rightShoulder, to: .rightHip),
            BodyConnection(from: .leftShoulder, to: .leftHip),
            BodyConnection(from: .rightHip, to: .leftHip),
            
            // Arm connections
            BodyConnection(from: .rightShoulder, to: .rightElbow),
            BodyConnection(from: .rightElbow, to: .rightWrist),
            BodyConnection(from: .leftShoulder, to: .leftElbow),
            BodyConnection(from: .leftElbow, to: .leftWrist),
            
            // Leg connections
            BodyConnection(from: .rightHip, to: .rightKnee),
            BodyConnection(from: .rightKnee, to: .rightAnkle),
            BodyConnection(from: .leftHip, to: .leftKnee),
            BodyConnection(from: .leftKnee, to: .leftAnkle)
        ]

        print("setupBodyConnections : \(bodyConnections)")
    }

    /// Called when a new video frame is available from the camera
    /// - Parameters:
    ///   - output: The output that produced the sample buffer
    ///   - sampleBuffer: The captured video frame
    ///   - connection: The connection through which the video was received
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Convert sample buffer to UIImage for potential capture
        currentFrame = convertSampleBufferToUIImage(sampleBuffer)
        
        Task {
            if let detectedPoints = await processFrame(sampleBuffer) {
                DispatchQueue.main.async {
                    self.detectedBodyParts = detectedPoints
                }
            }
        }
    }
    
    /// Convert CMSampleBuffer to UIImage
    /// - Parameter sampleBuffer: The camera frame buffer
    /// - Returns: UIImage representation of the frame
    private func convertSampleBufferToUIImage(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Processes a camera frame to detect human body pose
    /// - Parameter sampleBuffer: The captured video frame
    /// - Returns: Dictionary of detected joint positions if a pose was found, nil otherwise
    func processFrame(_ sampleBuffer: CMSampleBuffer) async -> [HumanBodyPoseObservation.JointName: CGPoint]? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
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

    /// Extracts joint positions from a pose observation with confidence filtering
    /// - Parameter observation: The human body pose observation from Vision framework
    /// - Returns: Dictionary mapping joint names to their positions in the view
    private func extractPoints(from observation: HumanBodyPoseObservation) -> [HumanBodyPoseObservation.JointName: CGPoint] {
        var detectedPoints: [HumanBodyPoseObservation.JointName: CGPoint] = [:]
        let humanJoints: [HumanBodyPoseObservation.PoseJointsGroupName] = [.face, .torso, .leftArm, .rightArm, .leftLeg, .rightLeg]
        
        for groupName in humanJoints {
            let jointsInGroup = observation.allJoints(in: groupName)
            for (jointName, joint) in jointsInGroup {
                if joint.confidence > 0.5 { // Only include joints with confidence score > 0.5
                    let point = joint.location.verticallyFlipped().cgPoint
                    detectedPoints[jointName] = point
                }
            }
        }
        return detectedPoints
    }
}
