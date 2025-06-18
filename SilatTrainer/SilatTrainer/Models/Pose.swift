//
//  Pose.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation
import UIKit
import AVFoundation

struct PoseData: Codable, Identifiable {
    var id: String { poseId }
    let poseId: String
    let joints: [String: JointCoordinate]
}

struct JointCoordinate: Codable {
    let x: Double
    let y: Double
}

struct Posture: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let imageName: String
    var image: UIImage?
    
    init(name: String, imageName: String, image: UIImage? = nil) {
        self.name = name
        self.imageName = imageName
        self.image = image
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Posture, rhs: Posture) -> Bool {
        lhs.id == rhs.id
    }
}
