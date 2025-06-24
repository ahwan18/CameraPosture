//
//  Pose.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import Vision
import SwiftData

struct PoseData: Codable, Identifiable {
    var id: String
    var name: String
    var keyPoints: [String: CGPoint]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case keyPoints
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Decode keyPoints as dictionary of arrays (e.g., [String: [Double]])
        let keyPointsDict = try container.decode([String: [CGFloat]].self, forKey: .keyPoints)
        
        // Convert arrays to CGPoint
        var keyPointsCGPoint = [String: CGPoint]()
        for (key, value) in keyPointsDict {
            if value.count >= 2 {
                keyPointsCGPoint[key] = CGPoint(x: value[0], y: value[1])
            }
        }
        
        self.keyPoints = keyPointsCGPoint
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        
        // Convert CGPoint to arrays
        var keyPointsArray = [String: [CGFloat]]()
        for (key, value) in keyPoints {
            keyPointsArray[key] = [value.x, value.y]
        }
        
        try container.encode(keyPointsArray, forKey: .keyPoints)
    }
}

struct JointCoordinate: Codable {
    let x: Double
    let y: Double
}

@Model
final class TrainingSession {
    var id: UUID
    var date: Date
    var jurus: String
    var duration: Int // in seconds
    var poseResults: [PoseResult]
    
    init(jurus: String, duration: Int, poseResults: [PoseResult] = []) {
        self.id = UUID()
        self.date = Date()
        self.jurus = jurus
        self.duration = duration
        self.poseResults = poseResults
    }
}

@Model
final class PoseResult {
    var id: UUID
    var poseName: String
    var poseNumber: Int
    var isCorrect: Bool
    var holdDuration: Double // in seconds
    
    init(poseName: String, poseNumber: Int, isCorrect: Bool, holdDuration: Double) {
        self.id = UUID()
        self.poseName = poseName
        self.poseNumber = poseNumber
        self.isCorrect = isCorrect
        self.holdDuration = holdDuration
    }
}
