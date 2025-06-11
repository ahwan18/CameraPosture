import Foundation
import UIKit

// MARK: - Posture Service Protocol

protocol PostureServiceProtocol {
    func getAllPoseInfos() -> [PoseInfo]
    func loadPostureImage(named imageName: String) -> UIImage?
    func getAllPostures() -> [Posture]
    func addNewPosture(image: UIImage, name: String) throws
    func deletePosture(with id: UUID) throws
}

// MARK: - Posture Service Implementation

class PostureService: PostureServiceProtocol {
    
    // MARK: - Properties
    
    static let shared = PostureService()
    
    private let fileManager = FileManager.default
    private var cachedPostures: [Posture] = []
    private let cacheQueue = DispatchQueue(label: "posture.cache.queue", attributes: .concurrent)
    
    // MARK: - Paths
    
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
    
    private var documentsPosturesURL: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Postures", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    private init() {
        setupDirectoriesAndDefaultPostures()
    }
    
    // MARK: - Public Methods
    
    func getAllPoseInfos() -> [PoseInfo] {
        // CRITICAL BUG FIX: Load poses alphabetically from Resources/Postures
        if let bundleURL = Bundle.main.url(forResource: "Postures", withExtension: nil, subdirectory: "Resources") {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
                let imageURLs = fileURLs.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
                
                if !imageURLs.isEmpty {
                    // Sort alphabetically by filename
                    let sortedURLs = imageURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
                    
                    let poses = sortedURLs.map { url in
                        let filename = url.lastPathComponent
                        let name = filename
                            .replacingOccurrences(of: ".jpg", with: "")
                            .replacingOccurrences(of: ".png", with: "")
                            .capitalized
                        
                        return PoseInfo(name: name, filename: filename)
                    }
                    
                    print("PostureService: Loaded \(poses.count) pose infos alphabetically from Resources/Postures")
                    return poses
                }
            } catch {
                print("PostureService: Error reading from bundle Resources/Postures: \(error)")
            }
        }
        
        // Fallback to documents directory
        guard let postureDirURL = posturesDirectoryURL else {
            print("PostureService: Could not get posture directory URL, using defaults")
            return getDefaultPoseInfos()
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: postureDirURL, includingPropertiesForKeys: nil)
            let imageURLs = fileURLs.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
            
            // Sort alphabetically
            let sortedURLs = imageURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            let poses = sortedURLs.map { url in
                let filename = url.lastPathComponent
                let name = filename
                    .replacingOccurrences(of: ".jpg", with: "")
                    .replacingOccurrences(of: ".png", with: "")
                    .capitalized
                
                return PoseInfo(name: name, filename: filename)
            }
            
            print("PostureService: Loaded \(poses.count) pose infos alphabetically from documents directory")
            return poses.isEmpty ? getDefaultPoseInfos() : poses
        } catch {
            print("PostureService: Error getting postures from documents: \(error)")
            return getDefaultPoseInfos()
        }
    }
    
    func loadPostureImage(named imageName: String) -> UIImage? {
        // First try in Resources/Postures bundle
        if let bundlePath = Bundle.main.path(forResource: imageName, ofType: nil, inDirectory: "Resources/Postures") {
            if let image = UIImage(contentsOfFile: bundlePath) {
                print("PostureService: Loaded \(imageName) from Resources/Postures")
                return image
            }
        }
        
        // Try documents directory
        if let postureDir = posturesDirectoryURL {
            let imageURL = postureDir.appendingPathComponent(imageName)
            if FileManager.default.fileExists(atPath: imageURL.path) {
                if let image = UIImage(contentsOfFile: imageURL.path) {
                    print("PostureService: Loaded \(imageName) from documents directory")
                    return image
                }
            }
        }
        
        // Try in Postures
        if let bundlePath = Bundle.main.path(forResource: imageName, ofType: nil, inDirectory: "Postures") {
            if let image = UIImage(contentsOfFile: bundlePath) {
                print("PostureService: Loaded \(imageName) from Postures directory")
                return image
            }
        }
        
        // Try as resource directly
        if let image = UIImage(named: imageName) {
            print("PostureService: Loaded \(imageName) as named resource")
            return image
        }
        
        // Try removing file extension and loading as named resource
        let nameWithoutExtension = imageName.replacingOccurrences(of: ".png", with: "").replacingOccurrences(of: ".jpg", with: "")
        if let image = UIImage(named: nameWithoutExtension) {
            print("PostureService: Loaded \(nameWithoutExtension) as named resource without extension")
            return image
        }
        
        print("PostureService: Could not load image: \(imageName)")
        return nil
    }
    
    func getAllPostures() -> [Posture] {
        return cacheQueue.sync {
            if cachedPostures.isEmpty {
                refreshCache()
            }
            return cachedPostures
        }
    }
    
    func addNewPosture(image: UIImage, name: String) throws {
        guard let documentsURL = documentsPosturesURL else {
            throw PostureServiceError.directoryNotFound
        }
        
        // Ensure directory exists
        if !fileManager.fileExists(atPath: documentsURL.path) {
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let sanitizedName = name.replacingOccurrences(of: " ", with: "_")
        let fileURL = documentsURL.appendingPathComponent("\(sanitizedName).jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PostureServiceError.imageConversionFailed
        }
        
        try imageData.write(to: fileURL)
        
        // Update cache
        cacheQueue.async(flags: .barrier) {
            self.refreshCache()
        }
        
        print("PostureService: Added new posture: \(name)")
    }
    
    func deletePosture(with id: UUID) throws {
        // Implementation for deleting posture
        // This would remove from documents directory and update cache
        throw PostureServiceError.notImplemented
    }
    
    // MARK: - Private Methods
    
    private func refreshCache() {
        let poseInfos = getAllPoseInfos()
        cachedPostures = poseInfos.compactMap { poseInfo in
            guard let image = loadPostureImage(named: poseInfo.filename) else {
                return nil
            }
            return Posture(name: poseInfo.name, imageName: poseInfo.filename, image: image)
        }
        print("PostureService: Cache refreshed with \(cachedPostures.count) postures")
    }
    
    private func setupDirectoriesAndDefaultPostures() {
        ensurePosturesDirectory()
        copyDefaultPosturesIfNeeded()
    }
    
    private func ensurePosturesDirectory() {
        guard let documentsURL = documentsPosturesURL else {
            print("PostureService: Could not access documents directory")
            return
        }
        
        if !FileManager.default.fileExists(atPath: documentsURL.path) {
            do {
                try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                print("PostureService: Created Postures directory at \(documentsURL.path)")
            } catch {
                print("PostureService: Failed to create Postures directory: \(error)")
            }
        }
    }
    
    private func copyDefaultPosturesIfNeeded() {
        guard let documentsURL = documentsPosturesURL else { return }
        
        // Check if postures already exist
        do {
            let existingFiles = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            if !existingFiles.isEmpty {
                return // Postures already exist
            }
        } catch {
            print("PostureService: Error checking for existing postures: \(error)")
        }
        
        // Copy default yoga images
        let defaultPostures = ["yoga1.png", "yoga2.png", "yoga3.png"]
        
        for postureName in defaultPostures {
            if let bundlePath = Bundle.main.path(forResource: postureName, ofType: nil, inDirectory: "Resources/Postures") {
                let sourceURL = URL(fileURLWithPath: bundlePath)
                let destURL = documentsURL.appendingPathComponent(postureName)
                
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    print("PostureService: Copied \(postureName) to documents")
                } catch {
                    print("PostureService: Failed to copy \(postureName): \(error)")
                }
            }
        }
    }
    
    private func getDefaultPoseInfos() -> [PoseInfo] {
        return [
            PoseInfo(name: "Yoga1", filename: "yoga1.png"),
            PoseInfo(name: "Yoga2", filename: "yoga2.png"),
            PoseInfo(name: "Yoga3", filename: "yoga3.png")
        ]
    }
}

// MARK: - Service Errors

enum PostureServiceError: Error, LocalizedError {
    case directoryNotFound
    case imageConversionFailed
    case fileNotFound
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "Postures directory not found"
        case .imageConversionFailed:
            return "Failed to convert image to data"
        case .fileNotFound:
            return "Posture file not found"
        case .notImplemented:
            return "Feature not implemented"
        }
    }
} 