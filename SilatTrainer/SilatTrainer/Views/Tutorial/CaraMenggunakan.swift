//
//  CaraMenggunakan.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//

import SwiftUI



struct CaraMenggunakan: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
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
                Spacer()
                HStack {
                    Text("Cara Menggunakan Aplikasi SIRAJ")
                        .font(.headline)
                        .padding(.bottom, 10)
                        .foregroundStyle(.white)
                    Spacer()
                }

                if let videoURL = Bundle.main.url(forResource: "vidTutor", withExtension: "mp4") {
                     VideoPlayerView(url: videoURL)
                        .frame(height: 580)
                    
                 } else {
                     Text("Video not found.")
                         .foregroundColor(.red)
                 }
                
                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 30)
            
        }
        .ignoresSafeArea()
//        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
        .navigationBarBackButtonHidden(true)
    }
}


#Preview {
    CaraMenggunakan()
}
