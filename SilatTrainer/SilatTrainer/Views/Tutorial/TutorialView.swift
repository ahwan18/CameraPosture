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
                                .foregroundColor(.black)
                                .font(.title3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity)
                                .fontWeight(.medium)
                                .padding(.leading, 10)
                                .offset(x: 10)
                            
                            Image("AssetListTutorial1")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 130, height: 130)
                                .offset(x: 10, y: 20)
                        }
                        
                    }
                    .frame(height: 100)
                    .background(.white)
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    
                    
                    Button(action: {
                        navigate(.bukuJurus)
                    }) {
                        HStack {
                            Text("Buku Jurus Tunggal Baku IPSI")
                                .foregroundColor(.black)
                                .font(.title3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity)
                                .fontWeight(.medium)
                                .padding(.leading, 20)
                            
                            Image("AssetListTutorial2")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 200)
                                .offset(x: 0,y: 20)
                        }
                    }
                    .frame(height: 100)
                    .background(.white)
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

