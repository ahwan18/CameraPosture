//
//  CameraPreviewView.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

//import SwiftUI
//import AVFoundation
//
//struct CameraPreviewView: UIViewRepresentable {
//    let session: AVCaptureSession
//    
//    func makeUIView(context: Context) -> UIView {
//        let view = UIView()
//        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
//        previewLayer.videoGravity = .resizeAspectFill
//        previewLayer.frame = UIScreen.main.bounds
//        view.layer.addSublayer(previewLayer)
//        return view
//    }
//
//    func updateUIView(_ uiView: UIView, context: Context) {}
//}

import SwiftUI
import UIKit
import AVFoundation

/// A SwiftUI view that wraps an AVCaptureSession and displays the camera feed
/// This component bridges UIKit's AVCaptureVideoPreviewLayer with SwiftUI
struct CameraPreviewView: UIViewRepresentable {

    // The capture session that provides video input from the camera
    // This should be initialized and configured before being passed to this view
    let session: AVCaptureSession
    
    /// Creates the UIView that will display the camera feed
    /// - Parameter context: The context in which this view is being created
    /// - Returns: A configured UIView with the camera preview layer attached
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        // Configure the preview layer to fill the view while maintaining aspect ratio
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        
        // Rotate the video by 90 degrees to display correctly in portrait orientation
        previewLayer.connection?.videoRotationAngle = 90
        
        // Add the preview layer to the view's layer hierarchy
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    /// Updates the view when SwiftUI layout changes occur
    /// - Parameters:
    ///   - uiView: The UIView previously created by makeUIView
    ///   - context: The current context of this view
    func updateUIView(_ uiView: UIView, context: Context) {
        Task {
            // When the view size changes, ensure the preview layer fills the new bounds
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}
