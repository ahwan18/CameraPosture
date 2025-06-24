import SwiftUI

/// Model untuk menyimpan hasil dari sesi latihan
struct TrainingResult {
    /// Durasi total latihan dalam detik
    let duration: Int
    
    /// Jumlah total pose yang seharusnya dilakukan
    let totalPoses: Int
    
    /// Jumlah pose yang berhasil dilakukan dengan benar dalam sekali percobaan
    let correctPoses: Int
    
    /// Detail untuk setiap pose
    let poseDetails: [PoseDetail]
}

/// Detail untuk setiap pose individual
struct PoseDetail {
    /// Nama pose (misalnya A1, A2, dll)
    let poseName: String
    
    /// ID unik untuk pose
    let poseId: String
    
    /// Apakah pose berhasil diselesaikan dengan benar dalam sekali percobaan
    let isCompletedCorrectly: Bool
    
    /// Waktu yang dibutuhkan untuk menyelesaikan pose (dalam detik)
    let timeToComplete: Double
    
    /// Gambar pose yang dilakukan user
    let userPoseImage: UIImage?
    
    /// Gambar pose yang seharusnya (referensi)
    let idealPoseImage: UIImage?
    
    /// Posisi joint-joint dari pose yang dilakukan user
    let jointPositions: [String: CGPoint]?
    
    /// Posisi joint-joint ideal (referensi)
    let idealJointPositions: [String: CGPoint]?
}

/// Service untuk menyimpan dan mengakses hasil latihan
class TrainingResultService {
    static let shared = TrainingResultService()
    
    /// Hasil latihan terakhir
    var lastTrainingResult: TrainingResult?
    
    private init() {}
    
    /// Menyimpan hasil latihan
    func saveTrainingResult(_ result: TrainingResult) {
        lastTrainingResult = result
        print("TrainingResultService: Hasil latihan berhasil disimpan")
        
        // Log detail hasil latihan
        print("- Durasi: \(result.duration) detik")
        print("- Pose benar: \(result.correctPoses) dari \(result.totalPoses)")
        print("- Detail pose yang tersimpan: \(result.poseDetails.count)")
        
        // Cek apakah semua pose memiliki data
        for (index, poseDetail) in result.poseDetails.enumerated() {
            let imageStatus = poseDetail.userPoseImage != nil ? "✓" : "✗"
            let jointsStatus = (poseDetail.jointPositions?.count ?? 0) > 0 ? "✓ (\(poseDetail.jointPositions?.count ?? 0) joints)" : "✗"
            print("  - A\(index+1): Gambar: \(imageStatus), Joints: \(jointsStatus), Benar: \(poseDetail.isCompletedCorrectly ? "Ya" : "Tidak")")
        }
    }
} 