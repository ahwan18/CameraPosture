import SwiftUI

struct TrainingView: View {
    @ObservedObject var viewModel: TrainingViewModel
    let startingPoseIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var showExitAlert = false
    
    var body: some View {
        ZStack {
            // Camera preview with pose overlay
            CameraPreviewView(
                cameraService: viewModel.cameraService,
                detectedPose: viewModel.cameraService.detectedPose,
                comparisonResult: viewModel.currentComparisonResult,
                showSkeleton: true
            )
            .edgesIgnoringSafeArea(.all)
            
            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    // Exit button
                    Button(action: {
                        showExitAlert = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    // Progress indicator
                    VStack(alignment: .trailing) {
                        Text(viewModel.progressText)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ProgressBar(
                            completedPoses: viewModel.trainingProgress.completedPoses.count,
                            totalPoses: 7
                        )
                        .frame(width: 150, height: 8)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
                .padding()
                
                Spacer()
                
                // Bottom info panel
                VStack(spacing: 16) {
                    // Current pose info
                    if let currentPose = viewModel.currentPose {
                        VStack(spacing: 8) {
                            Text(currentPose.name)
                                .font(.title3)
                                .bold()
                            
                            Text(currentPose.description)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.systemBackground).opacity(0.95))
                        .cornerRadius(12)
                    }
                    
                    // Hold timer and similarity
                    HStack(spacing: 20) {
                        // Hold timer
                        if viewModel.trainingProgress.isHoldingCorrectPose {
                            VStack {
                                Text("Tahan")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(viewModel.holdTimeRemaining)")
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundColor(.green)
                                
                                CircularProgressView(
                                    progress: viewModel.trainingProgress.holdDuration / TrainingConfig.requiredHoldDuration
                                )
                                .frame(width: 60, height: 60)
                            }
                        }
                        
                        // Similarity percentage
                        if let result = viewModel.currentComparisonResult {
                            VStack {
                                Text("Kemiripan")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(Int(result.overallSimilarity * 100))%")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(result.isCorrect ? .green : .orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    
                    // Warning message
                    if let warning = viewModel.warningMessage {
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            // Completion view
            if viewModel.showCompletionView {
                CompletionView(
                    onDismiss: {
                        dismiss()
                    }
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startTraining(from: startingPoseIndex)
        }
        .onDisappear {
            viewModel.stopTraining()
        }
        .alert("Keluar dari Latihan?", isPresented: $showExitAlert) {
            Button("Batal", role: .cancel) { }
            Button("Keluar", role: .destructive) {
                viewModel.stopTraining()
                dismiss()
            }
        } message: {
            Text("Progress latihan Anda akan hilang")
        }
    }
}

// Progress bar component
struct ProgressBar: View {
    let completedPoses: Int
    let totalPoses: Int
    
    var progress: Double {
        Double(completedPoses) / Double(totalPoses)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                
                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green)
                    .frame(width: geometry.size.width * CGFloat(progress))
            }
        }
    }
}

// Circular progress view
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)
        }
    }
}

// Completion view
struct CompletionView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 100))
                .foregroundColor(.yellow)
            
            Text("Selamat!")
                .font(.largeTitle)
                .bold()
            
            Text("Anda telah menyelesaikan\nJurus Satu IPSI")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: onDismiss) {
                Label("Selesai", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground).opacity(0.98))
    }
} 