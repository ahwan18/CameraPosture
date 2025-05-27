import SwiftUI
import Foundation

// Model to represent a pose option
struct PoseOption: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let image: UIImage?
    
    init(name: String, imageName: String) {
        self.name = name
        self.imageName = imageName
        self.image = PosturesManager.shared.loadPostureImage(named: imageName)
    }
    
    init(from poseInfo: PosturesManager.PoseInfo) {
        self.name = poseInfo.name
        self.imageName = poseInfo.filename
        self.image = PosturesManager.shared.loadPostureImage(named: poseInfo.filename)
    }
}

// ViewModel for pose selection
class PoseSelectionViewModel: ObservableObject {
    @Published var availablePoses: [PoseOption] = []
    @Published var selectedPose: PoseOption?
    
    init() {
        loadAvailablePoses()
    }
    
    func loadAvailablePoses() {
        // Get all pose info from the PosturesManager
        let poseInfos = PosturesManager.shared.getAllPostures()
        
        // Convert to PoseOption objects
        availablePoses = poseInfos.map { PoseOption(from: $0) }
        
        // If no poses found, add defaults (should not happen since manager handles this)
        if availablePoses.isEmpty {
            availablePoses = [
                PoseOption(name: "Pose 1", imageName: "p1.jpg"),
                PoseOption(name: "Pose 2", imageName: "p2.png")
            ]
        }
    }
    
    func selectPose(_ pose: PoseOption) {
        selectedPose = pose
    }
} 