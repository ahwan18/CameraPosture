//
//  ContentView.swift
//  C3-Posture
//
//  Created by Ahmad Kurniawan Ibrahim on 27/05/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            CameraPreview(viewModel: cameraViewModel)
                .ignoresSafeArea()
            
            if cameraViewModel.isSetupMode, let box = cameraViewModel.personBoundingBox {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let rect = CGRect(x: box.minX * w, y: (1 - box.maxY) * h, width: box.width * w, height: box.height * h)
                    Path { path in
                        path.addRect(rect)
                    }
                    .stroke(Color.blue, lineWidth: 3)
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        cameraViewModel.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                if cameraViewModel.isSetupMode {
                    Button(action: {
                        cameraViewModel.targetPersonBox = cameraViewModel.personBoundingBox
                        cameraViewModel.isSetupMode = false
                    }) {
                        Text("Set Person")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(15)
                    }
                    .padding(.bottom, 50)
                } else {
                    if !cameraViewModel.isPersonDetected {
                        Text("No person detected")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(15)
                            .padding(.bottom, 50)
                    } else if cameraViewModel.currentPoseObservation == nil {
                        Text("Please stand in the same position")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(15)
                            .padding(.bottom, 50)
                    } else {
                        HStack {
                            Image(systemName: cameraViewModel.isPostureGood ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(cameraViewModel.isPostureGood ? .green : .red)
                            
                            Text(cameraViewModel.isPostureGood ? "Good Posture!" : "Raise your arm to 30°")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(15)
                        .padding(.bottom, 10)
                        if !cameraViewModel.isLeftElbowGood || !cameraViewModel.isRightElbowGood {
                            VStack(spacing: 4) {
                                if !cameraViewModel.isLeftElbowGood {
                                    Text("Left arm not at 30°")
                                        .foregroundColor(.red)
                                        .bold()
                                }
                                if !cameraViewModel.isRightElbowGood {
                                    Text("Right arm not at 30°")
                                        .foregroundColor(.red)
                                        .bold()
                                }
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
        }
        .onAppear {
            cameraViewModel.startSession()
        }
        .onDisappear {
            cameraViewModel.stopSession()
        }
    }
}

#Preview {
    ContentView()
}
