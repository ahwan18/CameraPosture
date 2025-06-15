//
//  HomeView.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//


import SwiftUI

struct HomeView: View {
    @State private var showTutorial = false
    @State private var showLatihan = false

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
                    print("button mulai latihan di klik")
                    showLatihan = true // akan membuat view ini ditutupi oleh latihanView
                    print("show latihan  = \(showLatihan)")
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
        }
        .fullScreenCover(isPresented: $showLatihan){
            LatihanView()
        }

    }
}

#Preview {
    HomeView()
}
