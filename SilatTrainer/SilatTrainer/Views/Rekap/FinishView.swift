//
//  FinishView.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 14/06/25.
//

import SwiftUI

struct FinishView: View {
    @Environment(\.dismiss) var dismiss
    
    var navigate: (AppRoute) -> Void
    var body: some View {
        ZStack {
            Image(.finishBg)
                .ignoresSafeArea()
            
            VStack() {
                Spacer().frame(height: 450)
                
                Text("SELAMAT")
                    .font(.system(size: 37.5))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Kamu Sudah Berlatih Hari Ini")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .fontWeight(.medium)
                
                Spacer()
                    .frame(height: 170)
                
                Button(action: {
                    navigate(.rekap)
                }) {
                    Text("Lihat Ringkasan")
                        .font(.title3)
                }
                .padding()
                .padding(.horizontal, 50)
                .foregroundColor(.black)
                .fontWeight(.semibold)
                .background(.white)
                .cornerRadius(15)
                
                Spacer()
                    .frame(height: 50)
            }
            .padding(.bottom, 50)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    FinishView(navigate: { $0 })
}
