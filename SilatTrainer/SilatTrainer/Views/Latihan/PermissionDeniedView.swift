//
//  PermissionDeniedView.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 24/06/25.
//

import SwiftUI

struct PermissionDeniedView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.backgroundTutorial.ignoresSafeArea()
            
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Kembali")
                        .font(.title3)
                    Spacer()
                }
                .foregroundColor(.yellow)
                .padding(.leading, 20)
                .padding(.top, 10)
            }
            
            VStack(spacing: 20) {
                VStack {
                    
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Camera Access Needed")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Please enable camera access in Settings")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 10)
                
                
                
                Button(action: {
                    // Buka pengaturan aplikasi
                    if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    PermissionDeniedView()
}
