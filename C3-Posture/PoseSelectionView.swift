import SwiftUI
import PhotosUI

struct PoseSelectionView: View {
    @ObservedObject var viewModel: PoseSelectionViewModel
    @Binding var isPresented: Bool
    let onSelectPose: (Posture) -> Void
    
    @State private var showingImagePicker = false
    @State private var showingNameInput = false
    @State private var newPostureName = ""
    @State private var selectedImage: UIImage?
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.postures.isEmpty {
                    ContentUnavailableView(
                        "No Postures",
                        systemImage: "photo.on.rectangle",
                        description: Text("Add your first posture by tapping the + button")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(viewModel.postures) { pose in
                                PoseItemView(pose: pose) {
                                    onSelectPose(pose)
                                    isPresented = false
                                }
                            }
                        }
                        .padding()
                    }
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
        .onAppear {
            viewModel.loadPostures() // Refresh postures when view appears
        }
        .photosPicker(isPresented: $showingImagePicker,
                     selection: $selectedItems,
                     maxSelectionCount: 1,
                     matching: .images)
        .onChange(of: selectedItems) { items in
            guard let item = items.first else { return }
            loadTransferable(from: item)
        }
        .alert("Name Your Pose", isPresented: $showingNameInput) {
            TextField("Pose Name", text: $newPostureName)
            Button("Cancel", role: .cancel) {
                selectedImage = nil
                newPostureName = ""
                selectedItems = []
            }
            Button("Save") {
                if let image = selectedImage {
                    viewModel.addNewPose(image: image, name: newPostureName)
                }
                selectedImage = nil
                newPostureName = ""
                selectedItems = []
            }
        }
    }
    
    private func loadTransferable(from imageSelection: PhotosPickerItem) {
        imageSelection.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.selectedImage = image
                        self.showingNameInput = true
                        self.selectedItems = []
                    }
                }
            case .failure(let error):
                print("Error loading image: \(error)")
            }
        }
    }
}

struct PoseItemView: View {
    let pose: Posture
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(uiImage: pose.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)
                
                Text(pose.name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
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