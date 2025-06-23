//
//  BukuJurusIpsi.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//

import SwiftUI

struct BukuJurusIpsi: View {

    var body: some View {
        ZStack() {
            Color("BackgroundTutorial")
            
            VStack {
                Spacer()
                HStack {
                    Text("Kitab Jurus Tunggal Baku IPSI")
                        .font(.title3)
                        .padding(.bottom, 10)
                        .foregroundStyle(.white)
                    Spacer()
                }
                if let url = Bundle.main.url(forResource: "BukuPanduanJurusTunggalBakuIPSI", withExtension: "pdf") {
                    PDFViewer(url: url)
                        .frame(height: 600)
                        .cornerRadius(10)
                } else {
                    Text("PDF not found.")
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
    BukuJurusIpsi()
}
