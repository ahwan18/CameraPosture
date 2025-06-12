import Foundation
import SwiftUI
import PhotosUI
import Combine

class PoseConverterViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var currentPose: EditablePose?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showingExportAlert = false
    @Published var exportMessage = ""
    @Published var savedPoses: [EditablePose] = []
    @Published var showingShareSheet = false
    @Published var shareText = ""
    
    // Untuk drag and drop joint
    @Published var selectedJoint: JointName?
    @Published var isDragging = false
    
    func processSelectedImage(_ image: UIImage) {
        print("ViewModel: Processing image of size \(image.size)")
        isProcessing = true
        errorMessage = nil
        
        PoseDetectionService.shared.detectPose(from: image) { [weak self] result in
            DispatchQueue.main.async {
                print("ViewModel: Pose detection completed")
                self?.isProcessing = false
                
                switch result {
                case .success(let pose):
                    print("ViewModel: Pose detected successfully with \(pose.joints.count) joints")
                    self?.currentPose = pose
                    self?.selectedImage = image
                case .failure(let error):
                    print("ViewModel: Pose detection failed with error: \(error)")
                    self?.errorMessage = error.localizedDescription
                    self?.currentPose = nil
                }
            }
        }
    }
    
    func updateJointPosition(joint: JointName, to normalizedPosition: CGPoint) {
        guard var pose = currentPose,
              var editableJoint = pose.joints[joint] else { return }
        
        // Pastikan koordinat dalam range 0-1
        let clampedPosition = CGPoint(
            x: min(max(normalizedPosition.x, 0), 1),
            y: min(max(normalizedPosition.y, 0), 1)
        )
        
        editableJoint.normalizedPosition = clampedPosition
        editableJoint.confidence = 1.0 // Manual edit = full confidence
        pose.joints[joint] = editableJoint
        currentPose = pose
    }
    
    func toggleJointStatus(joint: JointName, to status: JointStatus) {
        guard var pose = currentPose,
              var editableJoint = pose.joints[joint] else { return }
        
        // Toggle logic: normal -> ignored -> important -> normal
        if editableJoint.status == status {
            editableJoint.status = .normal
        } else {
            editableJoint.status = status
        }
        
        pose.joints[joint] = editableJoint
        currentPose = pose
    }
    
    func deleteJoint(_ joint: JointName) {
        guard var pose = currentPose else { return }
        pose.joints.removeValue(forKey: joint)
        currentPose = pose
        
        // Clear selection if deleted joint was selected
        if selectedJoint == joint {
            selectedJoint = nil
        }
    }
    
    func updatePoseId(_ newId: String) {
        guard var pose = currentPose else { return }
        pose.poseId = newId
        currentPose = pose
    }
    
    func savePoseToCollection() {
        guard let pose = currentPose else { return }
        
        // Cek apakah pose dengan ID yang sama sudah ada
        if let index = savedPoses.firstIndex(where: { $0.poseId == pose.poseId }) {
            savedPoses[index] = pose
        } else {
            savedPoses.append(pose)
        }
        
        exportMessage = "Pose '\(pose.poseId)' berhasil disimpan ke koleksi"
        showingExportAlert = true
    }
    
    func shareCurrentPoseAsText() {
        guard let pose = currentPose else { return }
        
        do {
            let poseReference = pose.toPoseReference()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(poseReference)
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                shareText = """
                📱 Pose Data untuk SilatTrainer
                
                Pose ID: \(pose.poseId)
                
                JSON Data:
                \(jsonString)
                
                ---
                Copy JSON di atas dan paste ke SilatTrainer app
                """
                showingShareSheet = true
            }
            
        } catch {
            errorMessage = "Gagal mengonversi pose ke JSON: \(error.localizedDescription)"
        }
    }
    
    func copyCurrentPoseToClipboard() {
        guard let pose = currentPose else { return }
        
        do {
            let poseReference = pose.toPoseReference()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(poseReference)
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                UIPasteboard.general.string = jsonString
                exportMessage = "JSON berhasil disalin ke clipboard!"
                showingExportAlert = true
            }
            
        } catch {
            errorMessage = "Gagal mengonversi pose ke JSON: \(error.localizedDescription)"
        }
    }
    
    func shareAllPosesAsText() {
        guard !savedPoses.isEmpty else {
            errorMessage = "Tidak ada pose untuk dibagikan"
            return
        }
        
        do {
            var allPosesText = "📱 Semua Pose Data untuk SilatTrainer\n\n"
            
            for (index, pose) in savedPoses.enumerated() {
                let poseReference = pose.toPoseReference()
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(poseReference)
                
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    allPosesText += """
                    === Pose \(index + 1): \(pose.poseId) ===
                    
                    \(jsonString)
                    
                    
                    """
                }
            }
            
            allPosesText += """
            ---
            Total: \(savedPoses.count) poses
            Copy setiap JSON dan paste ke SilatTrainer app
            """
            
            shareText = allPosesText
            showingShareSheet = true
            
        } catch {
            errorMessage = "Gagal mengonversi poses ke JSON: \(error.localizedDescription)"
        }
    }
    
    func clearCurrentPose() {
        currentPose = nil
        selectedImage = nil
        selectedJoint = nil
        errorMessage = nil
    }
    
    // Helper untuk mendapatkan warna joint berdasarkan status
    func colorForJoint(_ joint: JointName) -> Color {
        guard let editableJoint = currentPose?.joints[joint] else { return .gray }
        
        switch editableJoint.status {
        case .normal:
            return .blue
        case .ignored:
            return .gray.opacity(0.5)
        case .important:
            return .red
        }
    }
} 