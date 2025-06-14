//
//  CaraMenggunakan.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//

import SwiftUI



struct CaraMenggunakan: View {

    var body: some View {
        VStack() {
            Text("Tutorial")
                .font(.title)
                .fontWeight(.bold)

            if let videoURL = Bundle.main.url(forResource: "latihan", withExtension: "mp4") {
                 VideoPlayerView(url: videoURL)
                     .frame(height: 650)
                     .padding()
             } else {
                 Text("Video not found.")
                     .foregroundColor(.red)
             }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}


#Preview {
    CaraMenggunakan()
}
