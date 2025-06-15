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
        VStack(spacing: 70) {
            VStack {
                Text("Selamat!!!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Kamu Sudah Berlatih Hari Ini")
                    .font(.title2)
            }
            
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .frame(width: 250, height: 250)
            Button(action: {
                navigate(.rekap)
            }) {
                Text("Lihat Rekap Latihan")
                    .font(.title3)
            }
            .padding()
            .padding(.horizontal, 50)
            .foregroundColor(.white)
            .background(.black)
            .cornerRadius(15)
            
        }
        .padding(.bottom, 50)
        .navigationBarBackButtonHidden(true)
    }
}
