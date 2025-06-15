//
//  FinishView.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 14/06/25.
//

import SwiftUI

struct FinishView: View {
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
            Button(action: {}) {
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
    }
}

#Preview {
    FinishView()
}
