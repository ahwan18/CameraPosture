//
//  TutorialView.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//
import SwiftUI

struct TutorialView: View {
    var navigate: (AppRoute) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color("BackgroundTutorial")
            
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
                .padding(.top, 70)
            }
            
            VStack {
                HStack {
                    Text("Informasi")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 20)
                        .foregroundStyle(.white)
                    Spacer()
                }
                
                
                VStack(spacing: 20) {
                    Button(action: {
                        navigate(.caraMenggunakan)
                    }) {
                        HStack {
                            Text("Cara Menggunakan Aplikasi SIRAJ")
                                .foregroundColor(.white)
                                .font(.title3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity)
                            
                            Image("AssetListTutorial1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 200)
                                .padding(.bottom, -15)
                        }
                        
                    }
                    .frame(height: 100)
                    .background(Color("BackgroundListTutorial"))
                    .cornerRadius(12)
                    
                    
                    Button(action: {
                        navigate(.bukuJurus)
                    }) {
                        HStack {
                            Text("Buku Jurus Tunggal Baku IPSI")
                                .foregroundColor(.white)
                                .font(.title3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity)
                            
                            Image("AssetListTutorial2")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 200)
                                .padding(.bottom, -15)
                        }
                    }
                    .frame(height: 100)
                    .background(Color("BackgroundListTutorial"))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 120)
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
    }
}


#Preview {
    TutorialView { route in
        print("Navigating to \(route)")
    }
}

