//
//  PoseComparison.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 17/06/25.
//

import Foundation
import Vision

struct PoseComparison {
    let currentPose: [HumanBodyPoseObservation.JointName: CGPoint]
    let referencePose: [String: JointCoordinate]
    let tolerance: CGFloat = 0.1
    
    struct Feedback {
        let joint: HumanBodyPoseObservation.JointName
        let direction: Direction
        let message: String
    }
    
    enum Direction {
        case up, down, left, right, forward, backward
    }
    
    func compare() -> [Feedback] {
        var feedbacks: [Feedback] = []
        
        for (jointName, currentPoint) in currentPose {
            if let referenceJoint = referencePose[jointName.rawValue] {
                let targetPoint = CGPoint(
                    x: referenceJoint.x,
                    y: referenceJoint.y
                )
                
                let dx = targetPoint.x - currentPoint.x
                let dy = targetPoint.y - currentPoint.y
                
                // Jika perbedaan posisi melebihi toleransi
                if abs(dx) > tolerance || abs(dy) > tolerance {
                    // Di sini calculateDirection() dipanggil
                    let direction = calculateDirection(from: currentPoint, to: targetPoint)
                    
                    // Di sini getFeedbackMessage() dipanggil
                    let message = getFeedbackMessage(for: jointName, direction: direction)
                    
                    // Buat feedback baru
                    feedbacks.append(Feedback(
                        joint: jointName,
                        direction: direction,
                        message: message
                    ))
                }
            }
        }
        
        return feedbacks
    }
    
    func calculateDirection(from current: CGPoint, to target: CGPoint) -> Direction {
        let dx = target.x - current.x
        let dy = target.y - current.y
        
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .down : .up
        }
    }
    
    // Fungsi untuk mendapatkan pesan feedback
    func getFeedbackMessage(for joint: HumanBodyPoseObservation.JointName, direction: Direction) -> String {
        switch (joint, direction) {
        case (.leftWrist, .up), (.rightWrist, .up):
            return "Angkat tangan lebih tinggi"
        case (.leftKnee, .down), (.rightKnee, .down):
            return "Tekuk lutut lebih dalam"
        case (.leftShoulder, .up), (.rightShoulder, .up):
            return "Angkat bahu lebih tinggi"
        case (.leftHip, .down), (.rightHip, .down):
            return "Turunkan pinggul"
        case (.leftElbow, .up), (.rightElbow, .up):
            return "Angkat siku lebih tinggi"
        case (.leftAnkle, .down), (.rightAnkle, .down):
            return "Tekuk pergelangan kaki"
        case (.leftWrist, .left), (.rightWrist, .right):
            return "Geser tangan ke \(direction == .left ? "kiri" : "kanan")"
        case (.leftWrist, .right), (.rightWrist, .left):
            return "Geser tangan ke \(direction == .left ? "kiri" : "kanan")"
        case (.leftKnee, .left), (.rightKnee, .right):
            return "Geser lutut ke \(direction == .left ? "kiri" : "kanan")"
        case (.leftKnee, .right), (.rightKnee, .left):
            return "Geser lutut ke \(direction == .left ? "kiri" : "kanan")"
        default:
            return "Sesuaikan posisi \(joint.rawValue)"
        }
    }
    
}
