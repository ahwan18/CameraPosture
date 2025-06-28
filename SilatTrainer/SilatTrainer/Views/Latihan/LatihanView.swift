import SwiftUI
import Vision
import UIKit
import SwiftData

struct LatihanView: View {
    var navigate: (AppRoute) -> Void
    var close: () -> Void

    @StateObject private var latihanVM: LatihanViewModel
    @StateObject private var cameraVM = CameraViewModel()
    @StateObject private var poseViewModel: PoseEstimationViewModel
    
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var showExitConfirmation = false
    
    @State private var showTutorial = false
    
    
    init(navigate: @escaping (AppRoute) -> Void, close: @escaping () -> Void) {
        self.navigate = navigate
        self.close = close
        
        let poseVM = PoseEstimationViewModel()
        _poseViewModel = StateObject(wrappedValue: poseVM)
        
        let latihanViewModel = LatihanViewModel(poseViewModel: poseVM)
        
        latihanViewModel.navigateToFinish = {
            print("LatihanView: navigateToFinish dipanggil, akan navigasi ke .finish")
            
            if Thread.isMainThread {
                print("Sudah di main thread, navigasi langsung")
                navigate(.finish)
            } else {
                print("Bukan di main thread, dispatch ke main")
                DispatchQueue.main.async {
                    navigate(.finish)
                }
            }
        }
        
        _latihanVM = StateObject(wrappedValue: latihanViewModel)
    }
    
    var body: some View {
        ZStack {
            if cameraVM.permissionStatus == .denied {
                PermissionDeniedView()
            } else {
                CameraPreviewView(session: cameraVM.session)
                    .ignoresSafeArea()
                
                PoseOverlayView(
                    bodyParts: poseViewModel.detectedBodyParts,
                    connections: poseViewModel.bodyConnections,
                    targetPose: latihanVM.currentTargetPose,
                    showGuideArrows: latihanVM.isAtOptimalDistance && !latihanVM.isPoseMatched && !latihanVM.showPoseTransition,
                    showFittingBox: latihanVM.phase != .evaluating,
                    isUserPositioned: latihanVM.isUserPositioned,
                    isPositioningPhase: latihanVM.phase == .positioning
                )
                
                VStack {
                    HStack {
                        Button(action: {
                            showExitConfirmation = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text("Kembali")
                                    .font(.title3)
                            }
                            .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        Text("Jurus 1")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 20)
                    
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("silatB"))
                                .frame(width: 140, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                            
                            Text(latihanVM.sessionElapsedTime)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("silatB"))
                                .frame(width: 140, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                            
                            Text(latihanVM.poseName)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(latihanVM.showPoseTransition ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: latihanVM.showPoseTransition)
                    
                    Spacer()
                    
                    if latihanVM.phase == .evaluating && !latihanVM.showPoseTransition {
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: latihanVM.isAtOptimalDistance ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(latihanVM.isAtOptimalDistance ? .green : .orange)
                                Text(latihanVM.isAtOptimalDistance ? "Posisi Optimal" : "Sesuaikan Jarak")
                                    .foregroundColor(latihanVM.isAtOptimalDistance ? .green : .orange)
                            }
                            .font(.system(size: 18, weight: .medium))
                            
                            HStack {
                                Button(action: {
                                    latihanVM.toggleMute()
                                }) {
                                    Image(systemName: latihanVM.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(22)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    latihanVM.togglePause()
                                }) {
                                    Image(systemName: latihanVM.isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(22)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            
                            if latihanVM.isAtOptimalDistance && !latihanVM.showPoseTransition {
                                if latihanVM.isPoseMatched {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 15)
                                                .fill(Color.black.opacity(0.8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 15)
                                                        .stroke(Color.white, lineWidth: 2)
                                                )
                                                .frame(width: 200, height: 120)
                                            
                                            VStack(spacing: 0) {
                                                Text("Tahan Posisi")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .padding(.top, 10)
                                                
                                                Text("\(latihanVM.countdownValue)")
                                                    .font(.system(size: 60, weight: .bold))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        
                                        ProgressView(value: latihanVM.holdProgress)
                                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                            .frame(width: 200)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                }
                
                if latihanVM.showFirstPoseView {
                    PosePertamaView()
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .zIndex(999)
                    .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
                    .edgesIgnoringSafeArea(.all)
                }
                
                if latihanVM.showPoseTransition {
                    PoseTransitionView(
                        poseNumber: latihanVM.currentPoseIndex + 2,
                        targetPose: latihanVM.nextTargetPose,
                        sessionElapsedTime: latihanVM.sessionElapsedTime
                    )
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .zIndex(999)
                    .position(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
                    .edgesIgnoringSafeArea(.all)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            latihanVM.cleanup()
            
            latihanVM.saveTrainingSession(to: modelContext)
        }
        .task {
            await cameraVM.checkPermission()
            cameraVM.delegate = poseViewModel
        }
        .onChange(of: poseViewModel.detectedBodyParts) { _, _ in
            latihanVM.update()
        }
        .alert("Akhiri Latihan?", isPresented: $showExitConfirmation) {
            Button("Batal", role: .cancel) { }
            Button("Akhiri", role: .destructive) {
                latihanVM.markRemainingPosesAsIncorrect()
                latihanVM.saveTrainingSession(to: modelContext)
                close()
            }
        } message: {
            Text("Jika kamu keluar sekarang, sesi latihan akan diakhiri dan semua gerakan yang belum selesai akan dianggap salah.")
        }
    }
    
    struct PoseTransitionView: View {
        let poseNumber: Int
        let targetPose: PoseData?
        let sessionElapsedTime: String
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Color.silatD
                        .ignoresSafeArea()
                    
                    VStack {
                        HStack {
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 100)
                        
                        
                        VStack(spacing: 30) {
                            Text("Gerakan Berikutnya")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("A\(poseNumber)")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            if targetPose != nil {
                                Image("A\(poseNumber)")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 600)
                                    .padding(.horizontal, 30)
                                    .padding(.bottom, 70)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea(.all)
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    struct PosePertamaView: View {
        
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Color.silatD
                        .ignoresSafeArea()
                    
                    VStack {
                        HStack {
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 100)
                        
                        
                        VStack(spacing: 30) {
                            Text("Gerakan Pertama")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("A1")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.yellow)
                            
                                Image("A1")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 600)
                                    .padding(.horizontal, 30)
                                    .padding(.bottom, 70)
                        }
                        
                        Spacer()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea(.all)
            .edgesIgnoringSafeArea(.all)
        }
    }
}
