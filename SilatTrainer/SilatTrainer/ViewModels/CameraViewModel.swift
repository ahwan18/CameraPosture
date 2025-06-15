//
//  CameraViewModel.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

//import AVFoundation
//
//class CameraViewModel: ObservableObject {
//    let session = AVCaptureSession()
//
//    init() {
//        setupSession()
//    }
//
//    private func setupSession() {
//        session.beginConfiguration()
//        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
//              let input = try? AVCaptureDeviceInput(device: device),
//              session.canAddInput(input) else { return }
//        session.addInput(input)
//        session.commitConfiguration()
//        session.startRunning()
//    }
//}

import SwiftUI
import AVFoundation
import Vision

@Observable
class CameraViewModel {

    // 1.
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let videoDataOutputQueue = DispatchQueue(label: "videoDataOutputQueue")
    private let videoDataOutput = AVCaptureVideoDataOutput()
    weak var delegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    // 2.
    func checkPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await setupCamera()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await setupCamera()
            }
        default:
            print("Camera permission denied")
        }
    }
    
    // 3.
    private func setupCamera() async {
        sessionQueue.async {
            self.session.beginConfiguration()
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                print("Failed to create video input")
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
            }
            
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            
            self.videoDataOutput.setSampleBufferDelegate(self.delegate, queue: self.videoDataOutputQueue)
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.session.canAddOutput(self.videoDataOutput) {
                self.session.addOutput(self.videoDataOutput)
            }
            
            if let connection = self.videoDataOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
                connection.isVideoMirrored = true
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
}
