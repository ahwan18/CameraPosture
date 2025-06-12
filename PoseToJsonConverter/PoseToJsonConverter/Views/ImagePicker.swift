import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
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
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Modern photo picker for iOS 16+
struct PhotoPicker: View {
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            preferredItemEncoding: .automatic
        ) {
            Label("Pilih dari Galeri", systemImage: "photo.on.rectangle")
        }
        .onChange(of: selectedItem) { oldItem, newItem in
            Task {
                print("PhotoPicker: selectedItem changed from \(String(describing: oldItem)) to \(String(describing: newItem))")
                
                if let item = newItem {
                    do {
                        if let data = try await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            print("PhotoPicker: Successfully loaded image with size \(image.size)")
                            await MainActor.run {
                                selectedImage = image
                            }
                        } else {
                            print("PhotoPicker: Failed to create UIImage from data")
                        }
                    } catch {
                        print("PhotoPicker: Error loading image: \(error)")
                    }
                } else {
                    print("PhotoPicker: newItem is nil")
                }
            }
        }
    }
} 