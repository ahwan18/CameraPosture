import SwiftUI
import Foundation
import Combine

// MARK: - Pose Selection ViewModel

class PoseSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var postures: [Posture] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Private Properties
    
    private let postureService: PostureServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(postureService: PostureServiceProtocol = PostureService.shared) {
        self.postureService = postureService
        loadPostures()
    }
    
    // MARK: - Public Methods
    
    func loadPostures() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let loadedPostures = self.postureService.getAllPostures()
            
            DispatchQueue.main.async {
                self.postures = loadedPostures
                self.isLoading = false
                
                if loadedPostures.isEmpty {
                    self.showErrorMessage("No postures found. Please check your pose images.")
                }
                
                print("PoseSelectionViewModel: Loaded \(loadedPostures.count) postures")
            }
        }
    }
    
    func addNewPose(image: UIImage, name: String) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.postureService.addNewPosture(image: image, name: name)
                
                DispatchQueue.main.async {
                    self.loadPostures() // Reload to show the new posture
                    print("PoseSelectionViewModel: Successfully added new pose: \(name)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showErrorMessage("Failed to add pose: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func refreshPostures() {
        loadPostures()
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Private Methods
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        
        // Auto-hide error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.clearError()
        }
    }
}

// MARK: - Helper Extensions

extension Posture {
    /// Create a PoseOption for backward compatibility with existing Views
    var asPoseOption: PoseOption {
        return PoseOption(name: name, imageName: imageName, image: image)
    }
}

// Legacy model for backward compatibility
struct PoseOption: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let image: UIImage?
    
    init(name: String, imageName: String, image: UIImage? = nil) {
        self.name = name
        self.imageName = imageName
        self.image = image
    }
    
    init(from posture: Posture) {
        self.name = posture.name
        self.imageName = posture.imageName
        self.image = posture.image
    }
} 