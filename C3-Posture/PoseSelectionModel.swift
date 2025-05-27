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
    @Published var postures: [Posture] = []
    private let posturesManager = PosturesManager.shared
    
    init() {
        loadPostures()
    }
    
    func loadPostures() {
        posturesManager.loadPostures() // Ensure PosturesManager has latest data
        postures = posturesManager.postures
    }
    
    func addNewPose(image: UIImage, name: String) {
        posturesManager.addNewPosture(image: image, name: name)
        loadPostures() // Reload postures immediately after adding
    }
} 