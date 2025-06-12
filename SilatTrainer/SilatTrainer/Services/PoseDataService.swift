import Foundation
import UIKit

class PoseDataService {
    static let shared = PoseDataService()
    
    private init() {}
    
    // Cache untuk pose references yang sudah dimuat
    private var loadedPoses: [String: PoseReference] = [:]
    
    // Data jurus dengan 7 pose
    let jurusPoses: [JurusPose] = [
        JurusPose(
            id: "jurus1_pose1",
            name: "Pose 1: Sikap Pasang",
            description: "Sikap awal dengan kuda-kuda tengah, tangan di depan dada",
            imageName: "silat_a",
            poseReference: nil
        ),
        JurusPose(
            id: "jurus1_pose2",
            name: "Pose 2: Langkah Kiri",
            description: "Langkah kaki kiri ke depan dengan tangkisan tangan kiri",
            imageName: "silat_b",
            poseReference: nil
        ),
        JurusPose(
            id: "jurus1_pose3",
            name: "Pose 3: Pukulan Depan",
            description: "Pukulan lurus tangan kanan dengan kuda-kuda depan",
            imageName: "silat_c",
            poseReference: nil
        ),
        JurusPose(
            id: "jurus1_pose4",
            name: "Pose 4: Tangkisan Atas",
            description: "Tangkisan ke atas dengan tangan kiri, badan condong",
            imageName: "silat_d",
            poseReference: nil
        ),
        JurusPose(
            id: "jurus1_pose5",
            name: "Pose 5: Sikutan",
            description: "Sikutan ke samping dengan putaran badan",
            imageName: "silat_e",
            poseReference: nil
        ),
        JurusPose(
            id: "jurus1_pose6",
            name: "Pose 6: Tendangan Depan",
            description: "Tendangan lurus ke depan dengan kaki kanan",
            imageName: "silat_f",
            poseReference: nil
        ),
        JurusPose(
            id: "jurus1_pose7",
            name: "Pose 7: Sikap Hormat",
            description: "Sikap penutup dengan posisi hormat",
            imageName: "silat_g",
            poseReference: nil
        )
    ]
    
    // Load pose reference dari Bundle atau Documents
    func loadPoseReference(for poseId: String) -> PoseReference? {
        // Check cache first
        if let cached = loadedPoses[poseId] {
            return cached
        }
        
        // Try loading from bundle first (pre-packaged data)
        if let pose = loadFromBundle(poseId: poseId) {
            loadedPoses[poseId] = pose
            return pose
        }
        
        // Try loading from documents directory (exported from PoseToJsonConverter)
        if let pose = loadFromDocuments(poseId: poseId) {
            loadedPoses[poseId] = pose
            return pose
        }
        
        return nil
    }
    
    private func loadFromBundle(poseId: String) -> PoseReference? {
        guard let url = Bundle.main.url(forResource: poseId, withExtension: "json") else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let pose = try JSONDecoder().decode(PoseReference.self, from: data)
            return pose
        } catch {
            print("Error loading pose from bundle: \(error)")
            return nil
        }
    }
    
    private func loadFromDocuments(poseId: String) -> PoseReference? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let poseDataFolder = documentsPath.appendingPathComponent("PoseData")
        let fileURL = poseDataFolder.appendingPathComponent("\(poseId).json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let pose = try JSONDecoder().decode(PoseReference.self, from: data)
            return pose
        } catch {
            print("Error loading pose from documents: \(error)")
            return nil
        }
    }
    
    // Load all poses for jurus
    func loadAllPosesForJurus() -> [JurusPose] {
        return jurusPoses.map { pose in
            var updatedPose = pose
            updatedPose.poseReference = loadPoseReference(for: pose.id)
            return updatedPose
        }
    }
    
    // Helper to get image for pose
    func getImage(for imageName: String) -> UIImage? {
        // First try to load from main bundle
        if let image = UIImage(named: imageName) {
            return image
        }
        
        // Try to load from file system (for images in jurus_1_ipsi folder)
        let imagePath = "jurus_1_ipsi/\(imageName).png"
        if let image = UIImage(contentsOfFile: imagePath) {
            return image
        }
        
        // Return placeholder if not found
        return UIImage(systemName: "figure.stand")
    }
} 