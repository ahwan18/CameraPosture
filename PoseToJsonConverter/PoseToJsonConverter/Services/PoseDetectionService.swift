import Foundation
import Vision
import UIKit

class PoseDetectionService {
    static let shared = PoseDetectionService()
    
    private init() {}
    
    func detectPose(from image: UIImage, completion: @escaping (Result<EditablePose, Error>) -> Void) {
        print("PoseDetectionService: Starting pose detection for image size \(image.size)")
        
        guard let cgImage = image.cgImage else {
            print("PoseDetectionService: Failed to get CGImage")
            completion(.failure(PoseDetectionError.invalidImage))
            return
        }
        
        let request = VNDetectHumanBodyPoseRequest { request, error in
            if let error = error {
                print("PoseDetectionService: Vision request failed with error: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNHumanBodyPoseObservation] else {
                print("PoseDetectionService: No observations in results")
                completion(.failure(PoseDetectionError.noPoseDetected))
                return
            }
            
            print("PoseDetectionService: Found \(observations.count) pose observations")
            
            guard let observation = observations.first else {
                print("PoseDetectionService: No poses detected")
                completion(.failure(PoseDetectionError.noPoseDetected))
                return
            }
            
            do {
                let editablePose = try self.createEditablePose(from: observation, imageData: image.pngData())
                print("PoseDetectionService: Successfully created editable pose with \(editablePose.joints.count) joints")
                completion(.success(editablePose))
            } catch {
                print("PoseDetectionService: Failed to create editable pose: \(error)")
                completion(.failure(error))
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("PoseDetectionService: Failed to perform request: \(error)")
            completion(.failure(error))
        }
    }
    
    private func createEditablePose(from observation: VNHumanBodyPoseObservation, imageData: Data?) throws -> EditablePose {
        var joints: [JointName: EditableJoint] = [:]
        
        // Ambil semua joint yang terdeteksi
        let recognizedJoints = try observation.recognizedPoints(.all)
        
        for (vnJointName, point) in recognizedJoints {
            guard let jointName = JointName.from(vnJoint: vnJointName),
                  point.confidence > 0.1,
                  !JointConnection.shouldIgnoreJoint(jointName) else { continue }
            
            // Vision framework memberikan koordinat dalam normalized space (0,1)
            // dengan origin di bottom-left, kita perlu flip Y untuk UI
            let normalizedPosition = CGPoint(
                x: point.location.x,
                y: 1.0 - point.location.y  // Flip Y untuk memutar 180 derajat
            )
            
            joints[jointName] = EditableJoint(
                normalizedPosition: normalizedPosition,
                confidence: CGFloat(point.confidence),
                status: .normal
            )
        }
        
        return EditablePose(
            poseId: "pose_\(UUID().uuidString.prefix(8))",
            joints: joints,
            imageData: imageData
        )
    }
}

enum PoseDetectionError: LocalizedError {
    case invalidImage
    case noPoseDetected
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Gambar tidak valid"
        case .noPoseDetected:
            return "Tidak ada pose terdeteksi dalam gambar"
        }
    }
} 