//
//  DataStorageProtocol.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import UIKit

/// Protocol defining data persistence and storage operations
protocol DataStorageProtocol {
    /// Save training session results
    /// - Parameters:
    ///   - sessionData: Dictionary containing session statistics
    ///   - sessionId: Unique identifier for the session
    /// - Returns: Boolean indicating success
    func saveSessionResults(_ sessionData: [String: Any], sessionId: String) -> Bool
    
    /// Load all training history
    /// - Returns: Array of session data dictionaries
    func loadTrainingHistory() -> [[String: Any]]
    
    /// Save a screenshot of a pose
    /// - Parameters:
    ///   - image: The image to save
    ///   - poseId: ID of the pose
    ///   - sessionId: ID of the session
    /// - Returns: Boolean indicating success
    func saveScreenshot(_ image: UIImage, forPose poseId: String, inSession sessionId: String) -> Bool
    
    /// Get screenshots for a specific pose
    /// - Parameter poseId: The pose ID
    /// - Returns: Array of images for the pose
    func getScreenshots(forPose poseId: String) -> [UIImage]
    
    /// Clear all stored data (for testing or privacy)
    /// - Returns: Boolean indicating success
    func clearAllData() -> Bool
} 