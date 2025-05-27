import SwiftUI
import AVFoundation  // Framework untuk kamera
import Vision        // Framework untuk Computer Vision (AI)
import Combine       // Framework untuk reactive programming
import ImageIO       // Untuk orientasi gambar

// MARK: - Camera View
struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            CameraPreview(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay for pose matching feedback
            if viewModel.isInPoseMatchingMode {
                PoseMatchingOverlay(viewModel: viewModel)
            }
            
            // Controls
            VStack {
                HStack {
                    Button(action: { viewModel.switchCamera() }) {
                        Image(systemName: "camera.rotate")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Status indicators
                HStack {
                    if viewModel.isPersonDetected {
                        Image(systemName: "person.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "person.slash")
                            .foregroundColor(.red)
                    }
                    
                    if viewModel.isPostureGood {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .font(.title)
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
                .padding()
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

// MARK: - Pose Matching Overlay
struct PoseMatchingOverlay: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        VStack {
            if let referenceImage = viewModel.selectedReferenceImage {
                Image(uiImage: referenceImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding()
            }
            
            Spacer()
            
            // Match status
            if viewModel.isPostureGood {
                Text("Pose Matched!")
                    .font(.title)
                    .foregroundColor(.green)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
            } else {
                Text("Adjust your pose")
                    .font(.title)
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Preview Provider
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}

