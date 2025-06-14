//
//  LatihanView.swift
//  SilatTrainer
//
//  Created by Ahmad Kurniawan Ibrahim on 14/06/25.
//

import SwiftUI

struct LatihanView: View {
    let poseData: [PoseData] = PoseLoader.loadPose()
    @StateObject private var cameraVM = CameraViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreviewView(session: cameraVM.session)
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button(action: {
                            
                        }) {
                            Image(systemName: "info.circle")
                                .padding(.leading, 37)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            
                        }) {
                            Image(systemName: "x.circle")
                                .padding(.trailing, 37)
                        }
                        
                    }
                    .font(.system(size: 32.25, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.vertical, 4)
                    
                    Text("Jurus 1")
                        .font(.system(size: 32, weight: .bold))
                    
                    if let firstIndex = poseData.firstIndex(where: { _ in true }),
                       let lastIndex = poseData.indices.last {
                        let startLabel = "A\(firstIndex + 1)"
                        let endLabel = "A\(lastIndex + 1)"
                        
                        Text("\(startLabel) / \(endLabel)")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.gray.opacity(0.14))
                            )
                    }
                    
                    Spacer()
                    
                    Text("Sesuaikan Posisi Anda di dalam Kotak")
                        .font(.system(size: 18, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 50)
                        .padding(.horizontal, 48)
                    
                    NavigationLink(destination: RekapLatihanView()) {
                        Text("Lanjut ke Rekap")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
        }
    }
}

#Preview {
    LatihanView()
}

