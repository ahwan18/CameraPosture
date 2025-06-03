import Foundation
import UIKit

class PosturesManager: ObservableObject {
    @Published var postures: [Posture] = []
    private let fileManager = FileManager.default
    
    static let shared = PosturesManager()
    
    // Simple structure to represent pose info without dependencies
    struct PoseInfo {
        let name: String
        let filename: String
    }
    
    // The path where we store posture images
    private var posturesDirectoryURL: URL? {
        // First try the app bundle Resources/Postures
        if let bundleURL = Bundle.main.url(forResource: "Postures", withExtension: nil, subdirectory: "Resources") {
            return bundleURL
        }
        
        // Then try the app bundle Postures directly
        if let bundleURL = Bundle.main.url(forResource: "Postures", withExtension: nil) {
            return bundleURL
        }
        
        // Then try documents directory
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Postures", isDirectory: true)
    }
    
    private init() {
        // Create postures directory in documents if it doesn't exist
        ensurePosturesDirectory()
        
        // Copy default postures if needed
        copyDefaultPosturesIfNeeded()
        
        loadPostures()
    }
    
    private func ensurePosturesDirectory() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access documents directory")
            return
        }
        
        let posturesURL = documentsURL.appendingPathComponent("Postures", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: posturesURL.path) {
            do {
                try FileManager.default.createDirectory(at: posturesURL, withIntermediateDirectories: true, attributes: nil)
                print("Created Postures directory at \(posturesURL.path)")
            } catch {
                print("Failed to create Postures directory: \(error)")
            }
        }
    }
    
    private func copyDefaultPosturesIfNeeded() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let posturesURL = documentsURL.appendingPathComponent("Postures", isDirectory: true)
        
        // Check if postures already exist
        do {
            let existingFiles = try FileManager.default.contentsOfDirectory(at: posturesURL, includingPropertiesForKeys: nil)
            if !existingFiles.isEmpty {
                // Postures already exist, no need to copy defaults
                return
            }
        } catch {
            print("Error checking for existing postures: \(error)")
        }
        
        // Updated posture files to match your actual yoga images
        let defaultPostures = ["yoga1.png", "yoga2.png", "yoga3.png"]
        
        // Try different source locations
        let possibleSourcePaths = [
            "Resources/Postures", // Check in Resources subdirectory
            "Postures", // Check in root bundle
            "" // Check in root bundle without subdirectory
        ]
        
        // Copy each file
        for posture in defaultPostures {
            var copied = false
            
            // Try each possible source path
            for sourcePath in possibleSourcePaths {
                if let bundlePath = Bundle.main.path(forResource: posture, ofType: nil, inDirectory: sourcePath) {
                    let sourceURL = URL(fileURLWithPath: bundlePath)
                    let destURL = posturesURL.appendingPathComponent(posture)
                    
                    do {
                        try FileManager.default.copyItem(at: sourceURL, to: destURL)
                        print("Copied \(posture) to documents from \(sourcePath)")
                        copied = true
                        break
                    } catch {
                        print("Failed to copy \(posture) from \(sourcePath): \(error)")
                    }
                }
            }
            
            // If still not copied, try with app bundle path directly
            if !copied {
                // Try directly from project root
                let bundleURL = Bundle.main.bundleURL.appendingPathComponent("Postures/\(posture)")
                if FileManager.default.fileExists(atPath: bundleURL.path) {
                    let destURL = posturesURL.appendingPathComponent(posture)
                    
                    do {
                        try FileManager.default.copyItem(at: bundleURL, to: destURL)
                        print("Copied \(posture) from bundle path")
                    } catch {
                        print("Failed to copy \(posture) from bundle path: \(error)")
                    }
                } else {
                    print("Could not find default posture file: \(posture)")
                }
            }
        }
    }
    
    // Get all available postures
    func getAllPostures() -> [PoseInfo] {
        // First try to load directly from bundle Resources/Postures
        if let bundleURL = Bundle.main.url(forResource: "Postures", withExtension: nil, subdirectory: "Resources") {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
                let imageURLs = fileURLs.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
                
                if !imageURLs.isEmpty {
                    let poses = imageURLs.map { url in
                        let filename = url.lastPathComponent
                        let name = filename
                            .replacingOccurrences(of: ".jpg", with: "")
                            .replacingOccurrences(of: ".png", with: "")
                            .capitalized
                        
                        return PoseInfo(name: name, filename: filename)
                    }
                    
                    print("Loaded \(poses.count) poses from bundle Resources/Postures: \(poses.map { $0.filename })")
                    return poses
                }
            } catch {
                print("Error reading from bundle Resources/Postures: \(error)")
            }
        }
        
        // Fallback to documents directory
        guard let postureDirURL = posturesDirectoryURL else {
            print("Could not get posture directory URL, using defaults")
            return defaultPoses()
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: postureDirURL, includingPropertiesForKeys: nil)
            let imageURLs = fileURLs.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
            
            let poses = imageURLs.map { url in
                let filename = url.lastPathComponent
                let name = filename
                    .replacingOccurrences(of: ".jpg", with: "")
                    .replacingOccurrences(of: ".png", with: "")
                    .capitalized
                
                return PoseInfo(name: name, filename: filename)
            }
            
            print("Loaded \(poses.count) poses from documents directory")
            return poses.isEmpty ? defaultPoses() : poses
        } catch {
            print("Error getting postures from documents: \(error)")
            return defaultPoses()
        }
    }
    
    // Default poses as fallback
    private func defaultPoses() -> [PoseInfo] {
        return [
            PoseInfo(name: "Yoga1", filename: "yoga1.png"),
            PoseInfo(name: "Yoga2", filename: "yoga2.png"),
            PoseInfo(name: "Yoga3", filename: "yoga3.png")
        ]
    }
    
    // Load a specific posture image
    func loadPostureImage(named imageName: String) -> UIImage? {
        // First try in Resources/Postures bundle
        if let bundlePath = Bundle.main.path(forResource: imageName, ofType: nil, inDirectory: "Resources/Postures") {
            if let image = UIImage(contentsOfFile: bundlePath) {
                print("Loaded \(imageName) from Resources/Postures")
                return image
            }
        }
        
        // Try documents directory
        if let postureDir = posturesDirectoryURL {
            let imageURL = postureDir.appendingPathComponent(imageName)
            if FileManager.default.fileExists(atPath: imageURL.path) {
                if let image = UIImage(contentsOfFile: imageURL.path) {
                    print("Loaded \(imageName) from documents directory")
                    return image
                }
            }
        }
        
        // Try in Postures
        if let bundlePath = Bundle.main.path(forResource: imageName, ofType: nil, inDirectory: "Postures") {
            if let image = UIImage(contentsOfFile: bundlePath) {
                print("Loaded \(imageName) from Postures directory")
                return image
            }
        }
        
        // Try as resource directly
        if let image = UIImage(named: imageName) {
            print("Loaded \(imageName) as named resource")
            return image
        }
        
        // Try removing file extension and loading as named resource
        let nameWithoutExtension = imageName.replacingOccurrences(of: ".png", with: "").replacingOccurrences(of: ".jpg", with: "")
        if let image = UIImage(named: nameWithoutExtension) {
            print("Loaded \(nameWithoutExtension) as named resource without extension")
            return image
        }
        
        print("Could not load image: \(imageName)")
        return nil
    }
    
    func loadPostures() {
        guard let posturesURL = getPosturesDirectoryURL() else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: posturesURL, includingPropertiesForKeys: nil)
            postures = contents.compactMap { url -> Posture? in
                guard let image = UIImage(contentsOfFile: url.path) else { return nil }
                return Posture(name: url.deletingPathExtension().lastPathComponent, image: image)
            }
        } catch {
            print("Error loading postures: \(error)")
        }
    }
    
    func addNewPosture(image: UIImage, name: String) {
        guard let posturesURL = getPosturesDirectoryURL() else { return }
        let sanitizedName = name.replacingOccurrences(of: " ", with: "_")
        let fileURL = posturesURL.appendingPathComponent("\(sanitizedName).jpg")
        
        // Save image to file
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            do {
                try imageData.write(to: fileURL)
                // Add to postures array
                let newPosture = Posture(name: sanitizedName, image: image)
                DispatchQueue.main.async {
                    self.postures.append(newPosture)
                }
            } catch {
                print("Error saving posture: \(error)")
            }
        }
    }
    
    private func getPosturesDirectoryURL() -> URL? {
        guard let projectURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let posturesURL = projectURL.appendingPathComponent("Postures")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: posturesURL.path) {
            do {
                try fileManager.createDirectory(at: posturesURL, withIntermediateDirectories: true)
            } catch {
                print("Error creating Postures directory: \(error)")
                return nil
            }
        }
        
        return posturesURL
    }
}

struct Posture: Identifiable {
    let id = UUID()
    let name: String
    let image: UIImage
} 