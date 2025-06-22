//
//  CameraServiceProtocol.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import AVFoundation
import Vision

/// Protocol defining camera access and processing capabilities
protocol CameraServiceProtocol {
    /// The video capture session
    var session: AVCaptureSession { get }
    
    /// The delegate receiving camera frame buffers
    var frameDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? { get set }
    
    /// Configure and initialize camera for use
    /// - Returns: Boolean indicating if setup was successful
    func setupCamera() async -> Bool
    
    /// Check and request camera permissions if needed
    /// - Returns: Boolean indicating if permission was granted
    func requestCameraPermission() async -> Bool
    
    /// Start camera capture session
    func startCapture()
    
    /// Stop camera capture session
    func stopCapture()
    
    /// Process a camera buffer to detect poses
    /// - Parameter buffer: The camera buffer frame
    /// - Returns: Dictionary of joint positions
    func processPoseFromBuffer(_ buffer: CMSampleBuffer) async -> [HumanBodyPoseObservation.JointName: CGPoint]?
} 