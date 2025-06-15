//
//  HomeView.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//


import SwiftUI

struct HomeView: View {
    var navigate: (AppRoute) -> Void
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 90) {
                (
                    Text("Latih")
                        .font(.largeTitle)
                    + Text("\nJurus Tunggal Baku\n IPSI")
                        .font(.title)
                        .fontWeight(.bold)
                    + Text("-mu")
                        .font(.title)
                )

                Button(action: {
                    navigate(.latihan)
                }) {
                    Text("Mulai Latihan")
                        .font(.title)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color("silatC"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Info button that triggers fullScreenCover
        }
    }
}

//#Preview {
//    HomeView()
//}
