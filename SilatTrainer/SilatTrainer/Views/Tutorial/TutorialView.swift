//
//  TutorialView.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//
import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        
        NavigationStack{
            
            ZStack(alignment: .topTrailing) {
                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "x.circle")
                        .resizable()
                        .frame(width: 32.25, height: 32.25)
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                }

                VStack {
                    Text("Tutorial")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 60)

                    VStack(spacing: 40) {
                        NavigationLink(destination: CaraMenggunakan()) {
                          Text("Cara Menggunakan Aplikasi")
                              .foregroundColor(.white)
                              .font(.title2)
                              .multilineTextAlignment(.center)
                              .frame(maxWidth: .infinity)
                              .padding(.vertical, 50)
                              .padding(.horizontal, 20)
                              .background(Color("silatC"))
                              .cornerRadius(12)
                      }

                        NavigationLink(destination: BukuJurusIpsi()) {
                          Text("Buka Jurus Tunggal Baku IPSI")
                              .foregroundColor(.white)
                              .font(.title2)
                              .multilineTextAlignment(.center)
                              .frame(maxWidth: .infinity)
                              .padding(.vertical, 50)
                              .padding(.horizontal, 20)
                              .background(Color("silatC"))
                              .cornerRadius(12)
                      }
                    }

                    Spacer()
                }
                .padding(.horizontal, 35)
                .padding(.top, 70)
            }

            
            
        }
        
    }
}


#Preview {
    TutorialView()
}
