import SwiftUI
import UIKit

struct PoseSelectionView: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: PoseSelectionViewModel
    @Binding var isPresented: Bool
    let onSelectPose: (Posture) -> Void
    
    // MARK: - State
    
    @State private var showingImagePicker = false
    @State private var newPoseName = ""
    @State private var showingAddPoseDialog = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading poses...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.postures.isEmpty {
                    emptyStateView
                } else {
                    poseGridView
                }
            }
            .navigationTitle("Select Pose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, isPresented: $showingImagePicker)
        }
        .alert("Add New Pose", isPresented: $showingAddPoseDialog) {
            TextField("Pose name", text: $newPoseName)
            Button("Add") {
                if let image = selectedImage, !newPoseName.isEmpty {
                    viewModel.addNewPose(image: image, name: newPoseName)
                    newPoseName = ""
                    selectedImage = nil
                }
            }
            Button("Cancel", role: .cancel) {
                selectedImage = nil
                newPoseName = ""
            }
        } message: {
            Text("Enter a name for the new pose")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            viewModel.loadPostures()
        }
        .onChange(of: selectedImage) { image in
            if image != nil {
                showingAddPoseDialog = true
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No poses available")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Add your first pose by tapping the + button")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Add Pose") {
                showingImagePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var poseGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150))
            ], spacing: 16) {
                ForEach(viewModel.postures) { posture in
                    PoseCard(posture: posture) {
                        onSelectPose(posture)
                        isPresented = false
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Pose Card

struct PoseCard: View {
    let posture: Posture
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Pose Image
                Group {
                    if let image = posture.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 140, height: 180)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                // Pose Name
                Text(posture.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    PoseSelectionView(
        viewModel: PoseSelectionViewModel(),
        isPresented: .constant(true),
        onSelectPose: { _ in }
    )
} 