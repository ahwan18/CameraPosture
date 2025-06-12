import SwiftUI

struct JurusGalleryView: View {
    @StateObject private var viewModel = TrainingViewModel()
    @State private var selectedPoseIndex: Int?
    
    let poses = PoseDataService.shared.jurusPoses
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Jurus Satu IPSI")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("Pelajari 7 pose dasar Pencak Silat")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Pose cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(poses.indices, id: \.self) { index in
                            PoseCard(
                                pose: poses[index],
                                index: index,
                                isSelected: selectedPoseIndex == index
                            )
                            .onTapGesture {
                                withAnimation {
                                    selectedPoseIndex = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Start training button
                    if let selectedIndex = selectedPoseIndex {
                        VStack(spacing: 16) {
                            Divider()
                            
                            NavigationLink(
                                destination: TrainingView(
                                    viewModel: viewModel,
                                    startingPoseIndex: selectedIndex
                                )
                            ) {
                                Label("Mulai Latihan dari Pose \(selectedIndex + 1)", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
}

struct PoseCard: View {
    let pose: JurusPose
    let index: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pose image
            if let image = PoseDataService.shared.getImage(for: pose.imageName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 150)
                    .overlay(
                        Image(systemName: "figure.stand")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
            }
            
            // Pose info
            VStack(alignment: .leading, spacing: 4) {
                Text("Pose \(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(pose.name.replacingOccurrences(of: "Pose \(index + 1): ", with: ""))
                    .font(.headline)
                    .lineLimit(1)
                
                Text(pose.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Status indicator
                HStack {
                    if pose.poseReference != nil {
                        Label("Data tersedia", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Label("Data belum ada", systemImage: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1), radius: isSelected ? 8 : 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    JurusGalleryView()
} 