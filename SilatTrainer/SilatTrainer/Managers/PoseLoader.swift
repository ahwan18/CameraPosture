//
//  PoseLoader.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import Foundation

class PoseLoader {
    static func loadPose() -> [PoseData] {
        guard let url = Bundle.main.url(forResource: "poseData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([PoseData].self, from: data) else {
            print("Failed to load poseData.json")
            return []
        }
        return decoded
    }
}
