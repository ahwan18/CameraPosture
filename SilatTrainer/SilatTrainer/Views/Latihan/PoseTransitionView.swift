//
//  PoseTransitionView.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 20/06/25.
//

import SwiftUI

// Pose transition view
struct PoseTransitionView: View {
    let poseNumber: Int
    let targetPose: PoseData?
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Gerakan Berikutnya")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                Text("A\(poseNumber)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.yellow)
                
                // Show preview of next pose
                if targetPose != nil {
                    Image("silat_a")  // You can dynamically load based on pose
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(.horizontal, 40)
                }
                
                Text("Siap dalam...")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("2")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.green)
            }
        }
    }
}
