//
//  BukuJurusIpsi.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//

import SwiftUI

struct BukuJurusIpsi: View {

    var body: some View {
        VStack() {
            Text("Buku Jurus Tunggal Baku IPSI")
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .multilineTextAlignment(.center)
            
            if let url = Bundle.main.url(forResource: "contoh", withExtension: "pdf") {
                PDFViewer(url: url)
                    .cornerRadius(10)
                    .padding()
            } else {
                Text("PDF not found.")
                    .foregroundColor(.red)
            }

            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}


#Preview {
    BukuJurusIpsi()
}
