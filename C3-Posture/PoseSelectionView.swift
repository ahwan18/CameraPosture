import SwiftUI

struct PoseSelectionView: View {
    @ObservedObject var viewModel: PoseSelectionViewModel
    @Binding var isPresented: Bool
    var onSelectPose: (PoseOption) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.availablePoses.isEmpty {
                    Text("No poses available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                            ForEach(viewModel.availablePoses) { pose in
                                PoseItemView(pose: pose)
                                    .onTapGesture {
                                        viewModel.selectPose(pose)
                                        onSelectPose(pose)
                                        isPresented = false
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select a Pose")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}

struct PoseItemView: View {
    let pose: PoseOption
    
    var body: some View {
        VStack {
            if let image = pose.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                    .cornerRadius(10)
                    .shadow(radius: 3)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 150)
                    .cornerRadius(10)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            
            Text(pose.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}

#Preview {
    PoseSelectionView(
        viewModel: PoseSelectionViewModel(),
        isPresented: .constant(true),
        onSelectPose: { _ in }
    )
} 