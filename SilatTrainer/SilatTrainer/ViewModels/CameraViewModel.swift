//
//  CameraViewModel.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import AVFoundation

class CameraViewModel: ObservableObject {
    let session = AVCaptureSession()

    init() {
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        session.commitConfiguration()
        session.startRunning()
    }
}
