//
//  DataStorageManager.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import UIKit

class DataStorageManager: DataStorageProtocol {
    static let shared = DataStorageManager()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let trainingsKey = "silat_trainer_sessions"
    
    private init() {}
    
    func saveSessionResults(_ sessionData: [String: Any], sessionId: String) -> Bool {
        // Get existing sessions
        var sessions = loadTrainingHistory()
        
        // Create new session with ID
        var sessionWithId = sessionData
        sessionWithId["id"] = sessionId
        sessionWithId["date"] = Date().timeIntervalSince1970
        
        // Add to sessions and save
        sessions.append(sessionWithId)
        
        // Convert to data
        guard let data = try? JSONSerialization.data(withJSONObject: sessions, options: []) else {
            print("Failed to serialize sessions data")
            return false
        }
        
        // Save to UserDefaults
        userDefaults.set(data, forKey: trainingsKey)
        return true
    }
    
    func loadTrainingHistory() -> [[String: Any]] {
        // Get data from UserDefaults
        guard let data = userDefaults.data(forKey: trainingsKey),
              let sessions = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            return []
        }
        
        return sessions
    }
    
    func saveScreenshot(_ image: UIImage, forPose poseId: String, inSession sessionId: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to data")
            return false
        }
        
        // Create directories if needed
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let poseDirectory = documentsDirectory.appendingPathComponent("poses/\(poseId)", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: poseDirectory.path) {
                try fileManager.createDirectory(at: poseDirectory, withIntermediateDirectories: true)
            }
            
            let timestamp = Date().timeIntervalSince1970
            let filename = "\(sessionId)_\(timestamp).jpg"
            let fileURL = poseDirectory.appendingPathComponent(filename)
            
            try data.write(to: fileURL)
            return true
        } catch {
            print("Error saving screenshot: \(error.localizedDescription)")
            return false
        }
    }
    
    func getScreenshots(forPose poseId: String) -> [UIImage] {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let poseDirectory = documentsDirectory.appendingPathComponent("poses/\(poseId)", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: poseDirectory.path) {
                return []
            }
            
            let fileURLs = try fileManager.contentsOfDirectory(at: poseDirectory, includingPropertiesForKeys: nil)
            let imageURLs = fileURLs.filter { $0.pathExtension == "jpg" }
            
            var images: [UIImage] = []
            for imageURL in imageURLs {
                if let image = UIImage(contentsOfFile: imageURL.path) {
                    images.append(image)
                }
            }
            
            return images
        } catch {
            print("Error getting screenshots: \(error.localizedDescription)")
            return []
        }
    }
    
    func clearAllData() -> Bool {
        // Clear UserDefaults sessions
        userDefaults.removeObject(forKey: trainingsKey)
        
        // Clear screenshots
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let posesDirectory = documentsDirectory.appendingPathComponent("poses", isDirectory: true)
        
        do {
            if fileManager.fileExists(atPath: posesDirectory.path) {
                try fileManager.removeItem(at: posesDirectory)
            }
            return true
        } catch {
            print("Error clearing data: \(error.localizedDescription)")
            return false
        }
    }
} 