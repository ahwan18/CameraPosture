//
//  FinishView.swift
//  SilatTrainer
//
//  Created by Rifki Hidayatullah on 14/06/25.
//

import SwiftUI

struct FinishView: View {
    @Environment(\.dismiss) var dismiss
    @State private var move: Bool = false
    @State private var isZoomedIn: Bool = false
    
    var navigate: (AppRoute) -> Void
    var body: some View {
        ZStack {
            if isZoomedIn {
                Image(.finishBg)
                    .resizable()
                    .frame(maxHeight: .infinity)
                    .scaleEffect(1.15)
                    .ignoresSafeArea()

            } else {
                Image(.finishBg2)
                    .resizable()
                    .frame(maxHeight: .infinity)
                    .scaleEffect(1.15)
                    .ignoresSafeArea()

            }
            
            
                Image(.sabukFinish)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 180)
                    .padding(.bottom, 200)
                    .offset(y: -85)
                    .scaleEffect(move ? 1.2 : 1)
                    .animation(.linear(duration: 2).repeatForever(autoreverses: true).speed(1.3), value: move)
                    .onAppear() {
                        move = true
                        startTogglingBackground()
                    }

            
            
            VStack() {
                Spacer().frame(height: 430)
                    
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
    
    func startTogglingBackground() {
        Timer.scheduledTimer(withTimeInterval: 1.55, repeats: true) { _ in
                isZoomedIn.toggle()
            }
        }
}



#Preview {
    FinishView(navigate: { $0 })
}
