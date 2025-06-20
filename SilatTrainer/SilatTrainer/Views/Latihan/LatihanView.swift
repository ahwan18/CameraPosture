//
//  LatihanView.swift (Refactored)
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import SwiftUI
import Vision
import Foundation

struct LatihanView: View {
    // MARK: - Navigation Dependencies
    var navigate: (AppRoute) -> Void
    var close: () -> Void
    
    // MARK: - Environment
    @Environment(\.dismiss) var dismiss
    
    // MARK: - ViewModel
    @StateObject private var viewModel = LatihanViewModel()
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: viewModel.cameraVM.session)
                .ignoresSafeArea()
            
            // Pose Overlay
            PoseOverlayView(
                bodyParts: viewModel.poseViewModel.detectedBodyParts,
                connections: viewModel.poseViewModel.bodyConnections,
                targetPose: viewModel.currentTargetPose,
                showGuideArrows: viewModel.showGuideArrows
            )
            
            // Main UI Content
            mainUIContent
                .opacity(viewModel.showPoseTransition ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: viewModel.showPoseTransition)
            
            // Pose Transition Overlay
            if viewModel.showPoseTransition {
                PoseTransitionView(
                    poseNumber: viewModel.currentPoseIndex + 2,
                    targetPose: viewModel.poseProgressManager.nextPose
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.endSession()
        }
        .onChange(of: viewModel.poseViewModel.detectedBodyParts) { _, _ in
            viewModel.handlePoseDetectionUpdate()
        }
    }
}

// MARK: - UI Components
private extension LatihanView {
    
    var mainUIContent: some View {
        VStack {
            topNavigationBar
            titleSection
            Spacer()
            statusIndicators
            instructionText
            actionButton
        }
    }
    
    var topNavigationBar: some View {
        HStack {
            Button(action: {
                viewModel.showTutorial = true
            }) {
                Image(systemName: "info.circle")
                    .padding(.leading, 37)
            }
            .fullScreenCover(isPresented: $viewModel.showTutorial) {
                TutorialView(navigate: navigate)
            }
            
            Spacer()
            
            Button(action: close) {
                Image(systemName: "x.circle")
                    .padding(.trailing, 37)
            }
        }
        .font(.system(size: 32.25, weight: .medium))
        .foregroundStyle(.black)
        .padding(.vertical, 4)
    }
    
    var titleSection: some View {
        VStack(spacing: 8) {
            Text("Jurus 1")
                .font(.system(size: 32, weight: .bold))
            
            Text(viewModel.currentPoseDisplayText)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 30)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.14))
                )
        }
    }
    
    var statusIndicators: some View {
        VStack(spacing: 10) {
            // Optimal Distance Indicator
            HStack {
                Image(systemName: viewModel.isAtOptimalDistance ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(viewModel.isAtOptimalDistance ? .green : .orange)
                Text(viewModel.isAtOptimalDistance ? "Posisi Optimal" : "Sesuaikan Jarak")
                    .foregroundColor(viewModel.isAtOptimalDistance ? .green : .orange)
            }
            .font(.system(size: 18, weight: .medium))
            
            // Pose Matching Indicator
            if viewModel.isAtOptimalDistance && !viewModel.showPoseTransition {
                HStack {
                    Image(systemName: viewModel.isPoseMatched ? "checkmark.circle.fill" : "target")
                        .foregroundColor(viewModel.isPoseMatched ? .green : .blue)
                    Text(viewModel.isPoseMatched ? "Pose Cocok - Tahan!" : "Sesuaikan Pose")
                        .foregroundColor(viewModel.isPoseMatched ? .green : .blue)
                }
                .font(.system(size: 16, weight: .medium))
                
                // Hold Progress and Countdown
                if viewModel.isPoseMatched {
                    holdProgressSection
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.8))
        )
    }
    
    var holdProgressSection: some View {
        VStack(spacing: 8) {
            Text("\(viewModel.countdownValue)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.green)
            
            ProgressView(value: viewModel.holdProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .frame(width: 200)
        }
    }
    
    var instructionText: some View {
        Text("Sesuaikan Posisi Anda di dalam Kotak")
            .font(.system(size: 18, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 50)
            .padding(.horizontal, 48)
    }
    
    var actionButton: some View {
        Button(action: {
            if viewModel.showCompletionMessage {
                navigate(.finish)
            } else {
                viewModel.skipExercise()
            }
        }) {
            Text(viewModel.showCompletionMessage ? "Selesai" : "Lewati")
        }
    }
}

