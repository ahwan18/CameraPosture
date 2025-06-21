import SwiftUI
import Vision
import UIKit

struct LatihanView: View {
    var navigate: (AppRoute) -> Void
    var close: () -> Void
    
    @StateObject private var latihanVM: LatihanViewModel
    @StateObject private var cameraVM = CameraViewModel()
    @StateObject private var poseViewModel: PoseEstimationViewModel
    
    @State private var showTutorial = false

    init(navigate: @escaping (AppRoute) -> Void, close: @escaping () -> Void) {
        self.navigate = navigate
        self.close = close
        
        let poseVM = PoseEstimationViewModel()
        _poseViewModel = StateObject(wrappedValue: poseVM)
        _latihanVM = StateObject(wrappedValue: LatihanViewModel(poseViewModel: poseVM))
    }
    
    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraVM.session)
                .ignoresSafeArea()
            
            PoseOverlayView(
                bodyParts: poseViewModel.detectedBodyParts,
                connections: poseViewModel.bodyConnections,
                targetPose: latihanVM.currentTargetPose,
                showGuideArrows: latihanVM.isAtOptimalDistance && !latihanVM.isPoseMatched && !latihanVM.showPoseTransition
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
                
                Text("Jurus 1")
                    .font(.system(size: 32, weight: .bold))
                
                Text("\(latihanVM.poseName)")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.5))
                    )
                    .overlay(
                       RoundedRectangle(cornerRadius: 10)
                          .stroke(Color.black, lineWidth:1)
                    )
                
                Spacer()
                
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: latihanVM.isAtOptimalDistance ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(latihanVM.isAtOptimalDistance ? .green : .orange)
                        Text(latihanVM.isAtOptimalDistance ? "Posisi Optimal" : "Sesuaikan Jarak")
                            .foregroundColor(latihanVM.isAtOptimalDistance ? .green : .orange)
                    }
                    .font(.system(size: 18, weight: .medium))
                    
                    if latihanVM.isAtOptimalDistance && !latihanVM.showPoseTransition {
                        HStack {
                            Image(systemName: latihanVM.isPoseMatched ? "checkmark.circle.fill" : "target")
                                .foregroundColor(latihanVM.isPoseMatched ? .green : .blue)
                            Text(latihanVM.isPoseMatched ? "Pose Cocok - Tahan!" : "Sesuaikan Pose")
                                .foregroundColor(latihanVM.isPoseMatched ? .green : .blue)
                        }
                        .font(.system(size: 16, weight: .medium))
                        
                        if latihanVM.isPoseMatched {
                            VStack(spacing: 8) {
                                Text("\(latihanVM.countdownValue)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.green)
                                
                                ProgressView(value: latihanVM.holdProgress)
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
                
//                Text("Sesuaikan Posisi Anda di dalam Kotak")
//                    .font(.system(size: 18, weight: .medium))
//                    .multilineTextAlignment(.center)
//                    .foregroundStyle(.black)
//                    .frame(maxWidth: .infinity)
//                    .padding(.bottom, 50)
//                    .padding(.horizontal, 48)
                
                Button(action: {
                    navigate(.finish)
                }) {
                    Text(latihanVM.showCompletionMessage ? "Selesai" : "Lewati")
                }
            }
            .opacity(latihanVM.showPoseTransition ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: latihanVM.showPoseTransition)
            
            if latihanVM.showPoseTransition {
                let poseTransitionView = PoseTransitionView(
                    poseNumber: latihanVM.currentPoseIndex + 2,
                    targetPose: latihanVM.nextTargetPose
                )
                poseTransitionView
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            latihanVM.cleanup()
        }
        .task {
            await cameraVM.checkPermission()
            cameraVM.delegate = poseViewModel
        }
        .onChange(of: poseViewModel.detectedBodyParts) { _, _ in
            latihanVM.updatePose()
        }
    }
}

struct PoseTransitionView: View {
    let poseNumber: Int
    let targetPose: PoseData?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Gerakan Berikutnya")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("A\(poseNumber)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.yellow)
                
                if targetPose != nil {
                    Image("silat_a")
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
