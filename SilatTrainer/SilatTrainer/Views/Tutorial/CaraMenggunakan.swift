//
//  CaraMenggunakan.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//

import SwiftUI



struct CaraMenggunakan: View {

    var body: some View {
        ZStack() {
            Color("BackgroundTutorial")
            
            VStack {
                Spacer()
                HStack {
                    Text("Cara Menggunakan Aplikasi SIRAJ")
                        .font(.title3)
                        .padding(.bottom, 10)
                        .foregroundStyle(.white)
                    Spacer()
                }

                if let videoURL = Bundle.main.url(forResource: "latihan", withExtension: "mp4") {
                     VideoPlayerView(url: videoURL)
                         .frame(height: 600)
                 } else {
                     Text("Video not found.")
                         .foregroundColor(.red)
                 }
                
                Spacer()
            }
            .padding(.horizontal, 30)
            
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
//        .navigationBarBackButtonHidden(true)
    }
}


#Preview {
    CaraMenggunakan()
}
