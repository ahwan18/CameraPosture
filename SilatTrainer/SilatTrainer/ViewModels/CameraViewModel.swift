import SwiftUI
import AVFoundation
import Vision
import Combine

/**
 * CameraViewModel
 *
 * Handles camera setup, permissions, and live video feed configuration for pose detection.
 * This view model manages the AVCaptureSession and processes camera frames for pose analysis.
 */
class CameraViewModel: ObservableObject {
    
    // - Properties
    enum PermissionStatus {
        case pending
        case denied
        case authorized
    }
    
    /// The capture session that manages camera input and output
    let session = AVCaptureSession()
    /// Serial queue for configuring the capture session
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    /// Queue for handling video frame processing
    private let videoDataOutputQueue = DispatchQueue(label: "videoDataOutputQueue")
    /// Output for receiving camera frames as sample buffers
    private let videoDataOutput = AVCaptureVideoDataOutput()
    /// Delegate that processes video sample buffers (typically the PoseEstimationViewModel)
    weak var delegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    @Published var permissionStatus: PermissionStatus = .pending
    
    // - Camera Permission
    
    /**
     * Checks and requests camera permissions, then sets up the camera if authorized.
     * This should be called when the view appears to ensure camera access.
     */
    func checkPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Camera permission already granted, proceed with setup
            await setupCamera()
            DispatchQueue.main.async {
                self.permissionStatus = .authorized
            }
        case .notDetermined:
            // Request camera access from the user
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await setupCamera()
                DispatchQueue.main.async {
                    self.permissionStatus = .authorized
                }
            } else {
                DispatchQueue.main.async {
                    self.permissionStatus = .denied
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionStatus = .denied
            }
            
        @unknown default:
            DispatchQueue.main.async {
                self.permissionStatus = .pending
            }
        }
    }
    
    // - Camera Setup
    
    /**
     * Configures the camera capture session with front camera input and video output.
     * Sets up proper orientation and mirroring for front-facing camera usage.
     */
    private func setupCamera() async {
        sessionQueue.async {
            self.session.beginConfiguration()
            
            // Create and add camera input device (front-facing camera)
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                print("Failed to create video input")
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
            }
            
            // Configure video output format (32-bit BGRA format)
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            
            // Set delegate to process video frames and configure output settings
            self.videoDataOutput.setSampleBufferDelegate(self.delegate, queue: self.videoDataOutputQueue)
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
            }
            
            // Adjust video orientation and mirroring for front camera
            if let connection = self.videoDataOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
                connection.isVideoMirrored = true
            }
            
            // Apply configuration and start the session
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
}
