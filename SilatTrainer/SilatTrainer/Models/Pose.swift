//
//  Pose.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation

struct PoseData: Codable, Identifiable {
    var id: String { poseId }
    let poseId: String
    let joints: [String: JointCoordinate]
}

struct JointCoordinate: Codable {
    let x: Double
    let y: Double
}
