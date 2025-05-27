import Foundation
import UIKit

class FileHelper {
    static let shared = FileHelper()
    
    private init() {}
    
    // Get the path to the Postures directory
    func getPosturesDirectoryPath() -> String? {
        // First, try to access the Postures directory through the app bundle
        if let bundlePath = Bundle.main.path(forResource: "Postures", ofType: nil) {
            return bundlePath
        }
        
        // Next, check if it's in the app bundle directly
        let bundlePath = Bundle.main.bundlePath + "/Postures"
        if FileManager.default.fileExists(atPath: bundlePath) {
            return bundlePath
        }
        
        // Check if it's in the documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            let posturesPath = documentsPath + "/Postures"
            if FileManager.default.fileExists(atPath: posturesPath) {
                return posturesPath
            }
            
            // If not found but we can create it
            do {
                try FileManager.default.createDirectory(atPath: posturesPath, withIntermediateDirectories: true, attributes: nil)
                return posturesPath
            } catch {
                print("Error creating Postures directory: \(error)")
            }
        }
        
        return nil
    }
    
    // Load an image from the Postures directory
    func loadImageFromPostures(named imageName: String) -> UIImage? {
        // First, try to load from the app bundle
        if let image = UIImage(named: "Postures/\(imageName)") {
            return image
        }
        
        // Try to load from various paths
        let possiblePaths = [
            // App bundle resource
            Bundle.main.path(forResource: "Postures/\(imageName)", ofType: nil),
            // Direct path in app bundle
            Bundle.main.bundlePath + "/Postures/\(imageName)",
            // Documents directory
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Postures/\(imageName)").path
        ]
        
        for path in possiblePaths.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: path), let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        
        // One last attempt with hard-coded paths for the known posture images
        let hardcodedPath = Bundle.main.bundlePath + "/Postures/\(imageName)"
        if FileManager.default.fileExists(atPath: hardcodedPath) {
            return UIImage(contentsOfFile: hardcodedPath)
        }
        
        return nil
    }
    
    // Get all posture image files
    func getAllPostureImageFiles() -> [String] {
        var imageFiles: [String] = []
        
        guard let posturePath = getPosturesDirectoryPath() else {
            // If we can't find the Postures directory, return the known default poses
            return ["p1.jpg", "p2.png"]
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: posturePath)
            imageFiles = files.filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }
        } catch {
            print("Error reading Postures directory: \(error)")
            // Return defaults if we can't read the directory
            imageFiles = ["p1.jpg", "p2.png"]
        }
        
        return imageFiles
    }
} 